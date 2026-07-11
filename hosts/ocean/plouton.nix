{ ... }:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';

  workloadUser = "plouton";
  workloadGroup = "plouton";
  workloadHome = "/var/lib/plouton";
in
{
  users.groups.${workloadGroup} = { };
  users.users.${workloadUser} = {
    isSystemUser = true;
    group = workloadGroup;
    home = workloadHome;
    createHome = false;
    description = "Plouton container workload user";
    subUidRanges = [
      {
        startUid = 427680;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 427680;
        count = 65536;
      }
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${workloadHome} 0700 ${workloadUser} ${workloadGroup} -"
    "d ${workloadHome}/data 0750 ${workloadUser} ${workloadGroup} -"
  ];

  keystone.os.containers.workloads.plouton = {
    enable = true;
    user = workloadUser;
    group = workloadGroup;
    home = workloadHome;
    createHome = false;
    description = "Plouton — containerized FastAPI and Astro SPA";
    image = "git.ncrmro.com/ncrmro/plouton:latest";
    serviceName = "plouton";
    containerName = "plouton";
    workingDir = workloadHome;
    ports = [ "0.0.0.0:17979:17979" ];
    container.extraLines = [
      # Always resolve the mutable latest tag on service start; this keeps
      # app-only deploys from reusing a previously cached rootless image.
      "Pull=always"
    ];
    volumes = [
      "${workloadHome}:${workloadHome}"
    ];
    registryLogin = {
      enable = true;
      registry = "git.ncrmro.com";
      username = "ncrmro";
      # Reuse the existing Forgejo package registry token until the secrets
      # repo grows a generic/plouton-specific registry token.
      passwordFile = "/run/agenix/vega-registry-token";
    };
    environment = {
      PORT = "17979";
      BIND_HOST = "0.0.0.0";
      DATABASE_URL = "file:${workloadHome}/data/plouton.db";
      HOME = workloadHome;
      NODE_ENV = "production";
    };
  };

  services.nginx.virtualHosts."plouton.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:17979";
      proxyWebsockets = true;
    };
  };
}
