# Vega OS-agent RPC sidecars and Pi MCP configuration.
#
# The only per-agent Vega containers are the pi-rpc bridges that keep Pi chat
# sessions/transcripts on the agent's own host. Vega MCP is centralized on ocean
# at https://vega.ncrmro.com/mcp and is consumed by Pi through
# pi-mcp-extension using request identity headers.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    filterAttrs
    listToAttrs
    mkIf
    nameValuePair
    ;

  hostName = config.networking.hostName;
  image = "git.ncrmro.com/ncrmro/vega:latest";
  mcpUrl = "https://vega.ncrmro.com/mcp";
  # Optional shared secret. If this runtime file exists, the activation script
  # adds Authorization: Bearer <token> to Pi's MCP config. The token is never
  # embedded in the Nix store.
  mcpTokenFile = "/run/agenix/vega-mcp-token";
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
  registryLogin = {
    enable = true;
    registry = "git.ncrmro.com";
    username = "ncrmro";
    passwordFile = "/run/agenix/vega-registry-token";
  };
  commonContainerLines = [
    "Pull=always"
  ];

  piWorkloadFor =
    name:
    nameValuePair "os-agent-${name}" {
      enable = true;
      user = agentUser name;
      group = "agents";
      home = agentHome name;
      createHome = false;
      description = "Vega pi-rpc bridge for ${name}";
      inherit image registryLogin;
      serviceName = "os-agent-${name}";
      containerName = "os-agent-${name}";
      workingDir = agentHome name;
      ports = [ "0.0.0.0:${toString (portFor name)}:${toString (portFor name)}" ];
      volumes = [ "${agentHome name}:${agentHome name}" ];
      environment = {
        PI_RPC_AGENT = name;
        PI_RPC_PORT = portFor name;
        PI_RPC_BIND_HOST = "0.0.0.0";
        PI_RPC_CWD = agentState name;
        PI_RPC_SESSION_DIR = "${agentState name}/sessions";
        PI_RPC_TRANSCRIPT_DIR = "${agentState name}/transcripts";
        HOME = agentHome name;
      };
      container.extraLines = commonContainerLines ++ [
        "Exec=vega-pi-rpc"
      ];
    };

  piMcpHomeFor =
    name:
    nameValuePair (agentUser name) {
      # Name sorts after Keystone's piMcpConfig activation entry so this can
      # merge the central Vega Streamable HTTP server into the generated Pi MCP
      # config without relying on home-manager's lib.hm from a NixOS module.
      home.activation.zzVegaPiMcpConfig = ''
        piAgentDir="$HOME/.pi/agent"
        piModelsConfig="$piAgentDir/models.json"
        piMcpConfig="$piAgentDir/mcp.json"
        mkdir -p "$piAgentDir"

        if [ -L "$piModelsConfig" ]; then
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
  keystone.os.containers.workloads = listToAttrs (map piWorkloadFor localAgentNames);

  home-manager.users = listToAttrs (map piMcpHomeFor localAgentNames);

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = map portFor localAgentNames;
}
