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
  workloadName = "os-agents";
  workloadUser = workloadName;
  workloadGroup = workloadName;
  workloadHome = "/var/lib/${workloadName}";
  stateDir = "${workloadHome}/state";
  ksConfigDir = "/home/${config.keystone.os.adminUsername}/repos/ncrmro/ks-config";
in
{
  users.groups.${workloadGroup} = { };
  users.users.${workloadUser} = {
    isSystemUser = true;
    group = workloadGroup;
    home = workloadHome;
    createHome = false;
    subUidRanges = [
      {
        startUid = 362144;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 362144;
        count = 65536;
      }
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${workloadHome} 0700 ${workloadUser} ${workloadGroup} -"
    "d ${stateDir} 0700 ${workloadUser} ${workloadGroup} -"
    "d ${stateDir}/data 0750 ${workloadUser} ${workloadGroup} -"
    # Let the app workload bind-mount and edit the admin-owned checkout without
    # making it an admin user or an OS-agent account.
    "a+ /home/${config.keystone.os.adminUsername} - - - - u:${workloadUser}:rx"
    "a+ /home/${config.keystone.os.adminUsername}/repos - - - - u:${workloadUser}:rx"
    "a+ /home/${config.keystone.os.adminUsername}/repos/ncrmro - - - - u:${workloadUser}:rx"
    "A+ ${ksConfigDir} - - - - u:${workloadUser}:rwX,d:u:${workloadUser}:rwX"
  ];

  keystone.os.containers.workloads.${workloadName} = {
    enable = true;
    user = workloadUser;
    group = workloadGroup;
    home = workloadHome;
    createHome = false;
    description = "Vega — containerized dashboard and API";
    image = "git.ncrmro.com/ncrmro/vega:latest";
    serviceName = workloadName;
    containerName = workloadName;
    workingDir = workloadHome;
    ports = [ "127.0.0.1:17878:17878" ];
    container.extraLines = [
      # Always resolve the mutable latest tag on service start; this keeps
      # app-only deploys from reusing a previously cached rootless image.
      "Pull=always"
    ];
    volumes = [
      "${workloadHome}:${workloadHome}"
      "${ksConfigDir}:${ksConfigDir}"
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
      HOME = workloadHome;
      NODE_ENV = "production";
      VEGA_CONFIG_PATH = "/etc/vega/config.yaml";
      VEGA_KS_CONFIG_DIR = ksConfigDir;
      GIT_CONFIG_COUNT = "1";
      GIT_CONFIG_KEY_0 = "safe.directory";
      GIT_CONFIG_VALUE_0 = ksConfigDir;
      GIT_AUTHOR_NAME = "Vega";
      GIT_AUTHOR_EMAIL = "vega@ncrmro.com";
      GIT_COMMITTER_NAME = "Vega";
      GIT_COMMITTER_EMAIL = "vega@ncrmro.com";
      PUBLIC_BROWSER_SERVER_URL = "https://vega.ncrmro.com";
      PUBLIC_SERVER_PORT = "17878";
      PI_RPC_DRAGO_URL = "http://ncrmro-workstation:7701";
      PI_RPC_LUCE_URL = "http://ocean:7702";
      # Ocean has no GPU. Route ollama traffic to ncrmro-workstation's
      # tailnet ollama (RX 9070 XT, currently hosts qwen3:4b + qwen3:32b).
      # URL must end in /v1 — pi-ai uses the OpenAI-compat
      # surface, not the native /api/* routes. See vega/server/src/routes/agent.ts
      # ModelRegistry.registerProvider override.
      OLLAMA_BASE_URL = "http://ncrmro-workstation:11434/v1";
      MAIN_SIDEBAR_AGENT_PROVIDER = "ollama";
      MAIN_SIDEBAR_AGENT_MODEL = "qwen3:4b";
      MAIN_SIDEBAR_AGENT_FALLBACK_PROVIDER = "ollama";
      MAIN_SIDEBAR_AGENT_FALLBACK_MODEL = "qwen3:4b";

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
      # Vega is served by the rootless Quadlet workload above. Keep nginx as
      # the stable TLS/tailnet boundary and forward to the host-loopback port
      # published by Podman.
      proxyPass = "http://127.0.0.1:17878";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
      '';
    };
  };
}
