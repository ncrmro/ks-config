# Vega OS-agent RPC services and Pi MCP configuration.
#
# Central Vega runs as the containerized os-agents workload on ocean. Per-agent
# pi-rpc bridges run natively as systemd user services under the corresponding
# OS-agent account so Pi sees the agent's Home Manager profile, Bridl config,
# credentials, and home directory directly.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    concatStringsSep
    filterAttrs
    listToAttrs
    mkIf
    nameValuePair
    ;

  hostName = config.networking.hostName;
  mcpUrl = "https://vega.ncrmro.com/mcp";
  # Optional shared secret. If this runtime file exists, the activation script
  # adds Authorization: Bearer <token> to Pi's MCP config. The token is never
  # embedded in the Nix store.
  mcpTokenFile = "/run/agenix/vega-mcp-token";
  vegaRepo = "/home/${config.keystone.os.adminUsername}/repos/ncrmro/vega";
  piRpcSource = "${vegaRepo}/code/pi-rpc/src/main.ts";
  piModelByAgent = {
    drago = "qwen3:4b";
    luce = "qwen3:4b";
  };
  piModelFor = name: piModelByAgent.${name} or "qwen3:4b";
  piModelsSource = name: "${toString config.keystone.systemFlake.path}/agents/${name}/pi/models.json";
  bridlProfilesFor =
    name:
    concatStringsSep "," [
      name
      "ks-fleet"
      "os-ks-agent-user"
    ];
  portsByAgent = {
    drago = 7701;
    luce = 7702;
  };
  portFor = name: portsByAgent.${name} or 7799;
  localAgents = filterAttrs (_: agent: agent.host == hostName) config.keystone.os.agents;
  localAgentNames = attrNames localAgents;
  hasLocalAgents = localAgentNames != [ ];
  agentUser = name: "agent-${name}";
  agentHome = name: "/home/${agentUser name}";
  agentState = name: "${agentHome name}/.local/state/vega/agents/${name}";

  agentServiceFor =
    name:
    let
      username = agentUser name;
      home = agentHome name;
    in
    {
      description = "Vega pi-rpc bridge for ${name}";
      wantedBy = [ "default.target" ];
      unitConfig.ConditionUser = username;
      environment = {
        PATH = lib.mkForce "/etc/profiles/per-user/${username}/bin:/run/wrappers/bin:/run/current-system/sw/bin:${
          lib.makeBinPath [
            pkgs.bun
            pkgs.coreutils
            pkgs.git
            pkgs.openssh
          ]
        }";
        HOME = home;
        KEYSTONE_CURRENT_HOST = hostName;
        KEYSTONE_FLEET_DOMAIN = if config.keystone.domain != null then config.keystone.domain else "";
        PI_RPC_AGENT = name;
        PI_RPC_PORT = toString (portFor name);
        PI_RPC_BIND_HOST = "0.0.0.0";
        PI_RPC_CWD = home;
        PI_RPC_SESSION_DIR = "${agentState name}/sessions";
        PI_RPC_TRANSCRIPT_DIR = "${agentState name}/transcripts";
        PI_RPC_BRIDL_PROFILES = bridlProfilesFor name;
        PI_RPC_PROVIDER = "ollama";
        PI_RPC_MODEL = piModelFor name;
        SSH_AUTH_SOCK = "/run/agent-${name}-ssh-agent/agent.sock";
        GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new";
      };
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = home;
        Restart = "always";
        RestartSec = "5s";
        TimeoutStopSec = "10s";
        SyslogIdentifier = "os-agent-${name}";
        LogRateLimitIntervalSec = 0;
      };
      script = ''
        set -euo pipefail
        if [ ! -f ${lib.escapeShellArg piRpcSource} ]; then
          echo "vega-pi-rpc source missing at ${piRpcSource}; sync the Vega checkout on ${hostName}" >&2
          exit 1
        fi
        exec ${pkgs.bun}/bin/bun ${lib.escapeShellArg piRpcSource}
      '';
    };

  piHomeFor =
    name:
    nameValuePair (agentUser name) {
      systemd.user.services."os-agent-${name}" = agentServiceFor name;

      # Name sorts after Keystone's piMcpConfig activation entry so this can
      # merge the central Vega Streamable HTTP server into the generated Pi MCP
      # config without relying on home-manager's lib.hm from a NixOS module.
      home.activation.zzVegaPiMcpConfig = ''
        piAgentDir="$HOME/.pi/agent"
        piModelsConfig="$piAgentDir/models.json"
        piMcpConfig="$piAgentDir/mcp.json"
        mkdir -p "$piAgentDir"

        piModelsSource=${lib.escapeShellArg (piModelsSource name)}
        if [ -r "$piModelsSource" ]; then
          ${pkgs.coreutils}/bin/cp "$piModelsSource" "$piModelsConfig.tmp"
          ${pkgs.coreutils}/bin/chmod 600 "$piModelsConfig.tmp"
          ${pkgs.coreutils}/bin/mv "$piModelsConfig.tmp" "$piModelsConfig"
        elif [ -L "$piModelsConfig" ]; then
          modelsTarget="$(${pkgs.coreutils}/bin/readlink -f "$piModelsConfig" || true)"
          if [ -n "$modelsTarget" ] && [ -r "$modelsTarget" ]; then
            ${pkgs.coreutils}/bin/cp "$modelsTarget" "$piModelsConfig.tmp"
            ${pkgs.coreutils}/bin/chmod 600 "$piModelsConfig.tmp"
            ${pkgs.coreutils}/bin/mv "$piModelsConfig.tmp" "$piModelsConfig"
          fi
        fi

        token=""
        if [ -r ${lib.escapeShellArg mcpTokenFile} ]; then
          token="$(${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg mcpTokenFile})"
        fi

        serverJson="$(${pkgs.jq}/bin/jq -n \
          --arg url ${lib.escapeShellArg mcpUrl} \
          --arg agent ${lib.escapeShellArg name} \
          --arg host ${lib.escapeShellArg hostName} \
          --arg token "$token" \
          '{
            transport: "streamable-http",
            url: $url,
            lifecycle: "eager",
            headers: ({
              "X-Keystone-Agent": $agent,
              "X-Keystone-Host": $host
            } + (if $token == "" then {} else {"Authorization": ("Bearer " + $token)} end))
          }'
        )"

        if [ -f "$piMcpConfig" ] && [ ! -L "$piMcpConfig" ]; then
          ${pkgs.jq}/bin/jq --argjson srv "$serverJson" \
            '. * {mcpServers: ((.mcpServers // {}) + {"ks-vega": $srv})}' \
            "$piMcpConfig" > "$piMcpConfig.tmp" \
            && mv "$piMcpConfig.tmp" "$piMcpConfig"
        else
          ${pkgs.jq}/bin/jq -n --argjson srv "$serverJson" \
            '{mcpServers: {"ks-vega": $srv}}' > "$piMcpConfig"
        fi
        chmod 600 "$piMcpConfig"
      '';
    };
in
mkIf hasLocalAgents {
  home-manager.users = listToAttrs (map piHomeFor localAgentNames);

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = map portFor localAgentNames;
}
