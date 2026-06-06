{ inputs, config, lib, pkgs, ... }:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';

  # Materialise keystone.os.agents as a YAML on disk so vega's
  # /api/agents reflects the fleet's declared identities at startup,
  # not lazily after each agent first POSTs a report. Schema is owned
  # by vega (server/src/config.ts); see vega/code/docs/config-yaml.md.
  vegaConfig = (pkgs.formats.yaml { }).generate "vega-config.yaml" {
    agents = lib.mapAttrsToList (name: agent: {
      inherit name;
      inherit (agent) host fullName;
    }) config.keystone.os.agents;
    defaultAgent = config.keystone.os.defaultAgent;
  };
in
{
  imports = [ inputs.vega.nixosModules.default ];

  services.vega = {
    enable = true;
    # vega-server runs AS this agent's user, with HOME=/home/agent-<slug>.
    # That places ks-config writes (SOUL.md/AGENTS.md/...) into the symlink
    # keystone provisions into the agent home, which points at the admin's
    # canonical checkout. Coincidentally also matches VEGA_DEFAULT_OS_AGENT
    # below (the UI persona), but they're kept as separate references so a
    # future host can split them.
    operatorAgent = config.keystone.os.defaultAgent;
    bindHost = "127.0.0.1";
    port = 17878;
    configFile = vegaConfig;
    # The browser is reached at https://vega.ncrmro.com via nginx; the
    # SSR fetches loop back to this same process. The browser-side base
    # URL needs the public host (PUBLIC_BROWSER_SERVER_URL). The SSR
    # base URL needs to point at the listener's own port — vega's
    # api.ts now picks $PORT when PUBLIC_SERVER_PORT is unset, but we
    # also pin it explicitly here as defense in depth: ocean's 7878
    # belongs to Radarr (servarr.nix), and an SSR loop into a 401-
    # returning neighbour is the worst kind of silent failure.
    #
    # TODO(keystone): assign-time port-conflict detection across
    # `services.*` modules keystone owns. Vega/Radarr collision on
    # ocean only surfaced as a 401 in rendered HTML; a doctor check or
    # a central port registry would catch it before deploy.
    environment = {
      PUBLIC_BROWSER_SERVER_URL = "https://vega.ncrmro.com";
      PUBLIC_SERVER_PORT = "17878";
      # Ocean has no GPU. Route ollama traffic to ncrmro-workstation's
      # tailnet ollama (RX 9070 XT, hosts nemotron-3-nano:4b + qwen3:32b
      # + friends). URL must end in /v1 — pi-ai uses the OpenAI-compat
      # surface, not the native /api/* routes. See vega/server/src/routes/agent.ts
      # ModelRegistry.registerProvider override.
      OLLAMA_BASE_URL = "http://ncrmro-workstation:11434/v1";

      # Vega's website surfaces the fleet's default OS agent as its in-process
      # LLM persona (label, placeholders, voice). The slug + fullName flow into
      # SSR via these env vars; React islands receive them as hydration props.
      VEGA_DEFAULT_OS_AGENT = config.keystone.os.defaultAgent;
      VEGA_DEFAULT_OS_AGENT_FULL_NAME =
        config.keystone.os.agents.${config.keystone.os.defaultAgent}.fullName;
    };
  };

  services.nginx.virtualHosts."vega.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:17878";
      proxyWebsockets = true;
    };
  };
}
