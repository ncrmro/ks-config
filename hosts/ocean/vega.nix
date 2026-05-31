{ inputs, ... }:
let
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
in
{
  imports = [ inputs.vega.nixosModules.default ];

  services.vega = {
    enable = true;
    bindHost = "127.0.0.1";
    port = 7878;
  };

  services.nginx.virtualHosts."vega.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:7878";
      proxyWebsockets = true;
    };
  };
}
