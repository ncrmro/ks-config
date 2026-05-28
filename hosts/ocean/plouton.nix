{
  config,
  inputs,
  pkgs,
  ...
}:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
  authEnvFile = "/var/lib/plouton-web/auth.env";
in
{
  imports = [ inputs.plouton.nixosModules.default ];

  services.plouton-web = {
    enable = true;
    environment = {
      AUTH_USERNAME = "ncrmro";
    };
    environmentFile = authEnvFile;
  };

  systemd.services.plouton-web-bootstrap = {
    description = "Bootstrap plouton runtime credentials";
    before = [ "plouton-web.service" ];
    requiredBy = [ "plouton-web.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
            set -euo pipefail
            install -d -m 0700 /var/lib/plouton-web

            if [ -e ${authEnvFile} ]; then
              exit 0
            fi

            umask 077
            auth_secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
            auth_password="$(${pkgs.openssl}/bin/openssl rand -hex 24)"

            cat > ${authEnvFile} <<EOF
      AUTH_SECRET=$auth_secret
      AUTH_PASSWORD=$auth_password
      EOF
    '';
  };

  systemd.services.plouton-web = {
    after = [ "plouton-web-bootstrap.service" ];
    requires = [ "plouton-web-bootstrap.service" ];
  };

  services.nginx.virtualHosts."plouton.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.plouton-web.port}";
      proxyWebsockets = true;
    };
  };
}
