{ config, inputs, ... }:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
in
{
  age.secrets.miniflux-admin = {
    file = "${inputs.agenix-secrets}/secrets/miniflux-admin.age";
    owner = "root";
    mode = "0400";
  };

  services.miniflux = {
    enable = true;
    createDatabaseLocally = true;
    config = {
      LISTEN_ADDR = "0.0.0.0:8070";
    };
    adminCredentialsFile = config.age.secrets.miniflux-admin.path;
  };

  services.nginx.virtualHosts."miniflux.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8070";
      proxyWebsockets = true;
    };
  };
}
