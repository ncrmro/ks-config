{ inputs, ... }:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
in
{
  imports = [ inputs.plouton.nixosModules.default ];

  services.plouton = {
    enable = true;
    bindHost = "127.0.0.1";
    port = 17979;
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
