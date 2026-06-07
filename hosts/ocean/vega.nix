{
  config,
  lib,
  pkgs,
  ...
}:
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
let
  operatorAgent = config.keystone.os.defaultAgent;
  agentUser = "agent-${operatorAgent}";
  agentHome = "/home/${agentUser}";
  stateDir = "${agentHome}/.local/share/vega";
in
{
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 ${agentUser} agents -"
    "d ${stateDir}/data 0750 ${agentUser} agents -"
  ];

  keystone.os.containers.workloads.vega = {
    enable = true;
    user = agentUser;
    group = "agents";
    home = agentHome;
    createHome = false;
    description = "Vega — containerized dashboard and API";
    image = "git.ncrmro.com/ncrmro/vega:latest";
    serviceName = "vega";
    containerName = "vega";
    workingDir = agentHome;
    ports = [ "127.0.0.1:17878:17878" ];
    container.extraLines = [
      # Always resolve the mutable latest tag on service start; this keeps
      # app-only deploys from reusing a previously cached rootless image.
      "Pull=always"
    ];
    volumes = [
      "${agentHome}:${agentHome}"
      "${vegaConfig}:/etc/vega/config.yaml:ro"
    ];
    registryLogin = {
      enable = true;
      registry = "git.ncrmro.com";
      username = "ncrmro";
      passwordFile = "/run/agenix/vega-registry-token";
    };
    environment = {
      PORT = "17878";
      # Bind inside the container; Podman publishes only to host loopback.
      BIND_HOST = "0.0.0.0";
      DATABASE_URL = "file:${stateDir}/data/vega.db";
      HOME = agentHome;
      NODE_ENV = "production";
      VEGA_CONFIG_PATH = "/etc/vega/config.yaml";
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
      VEGA_DEFAULT_OS_AGENT = operatorAgent;
      VEGA_DEFAULT_OS_AGENT_FULL_NAME = config.keystone.os.agents.${operatorAgent}.fullName;
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
