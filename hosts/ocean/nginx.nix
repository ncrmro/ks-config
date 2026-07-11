# Manual vhosts for non-keystone services.
# ACME, base nginx, and firewall are managed by keystone.server.acme + keystone nginx module.
#
# NixOS nginx is a thin TLS front on 80/443. Routing and access control for
# app traffic live in the k3s ingress-nginx (hostPort 127.0.0.1:8080):
#   - k8s-native workloads (personal website) define their own Ingress
#   - NixOS-hosted services get Ingress objects from ./k3s-host-services.nix,
#     including the Tailscale/headscale whitelist rules
{ ... }:
let
  k8sIngressHttp = "127.0.0.1:8080";
  # Allow/deny config for Tailscale-only services
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
in
{
  # Everything routed via the cluster ingress. Per-host body-size limits and
  # buffering are enforced by Ingress annotations, so the front must not cap
  # or buffer here.
  services.nginx.virtualHosts."ncrmro.com" = {
    serverAliases = [
      "jellyfin.ncrmro.com"
      "radarr.ncrmro.com"
      "sonarr.ncrmro.com"
      "prowlarr.ncrmro.com"
      "bazarr.ncrmro.com"
      "lidarr.ncrmro.com"
      "readarr.ncrmro.com"
      "jellyseerr.ncrmro.com"
      "transmission.ncrmro.com"
      "sabnzbd.ncrmro.com"
      "home.ncrmro.com"
      "adguard.home.ncrmro.com"
      "photos.ncrmro.com"
      "git.ncrmro.com"
    ];
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = ''
      client_max_body_size 0;
    '';
    locations."/" = {
      proxyPass = "http://${k8sIngressHttp}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_request_buffering off;
      '';
    };
  };

  # Stalwart Mail Admin - Tailscale only. Stays on native nginx: the JMAP
  # listener is keystone-managed and bound to loopback, so the cluster
  # ingress cannot reach it.
  services.nginx.virtualHosts."mail.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8082";
      proxyWebsockets = true;
    };
  };
}
