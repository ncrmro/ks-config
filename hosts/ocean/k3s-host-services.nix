# Routes HTTP for NixOS-hosted services through the in-cluster ingress-nginx.
# Each service here gets a selector-less Service + Endpoints pointing back at
# the host, plus an Ingress.
#
# Access control moves from nginx allow/deny blocks to ingress-nginx
# whitelist-source-range annotations.
{ lib, config, ... }:
let
  # Headscale VPN (Tailscale CGNAT) ranges — mirrors the old nginx tailscaleOnly block
  tailscaleOnly = "100.64.0.0/10,fd7a:115c:a1e0::/48";
  tailscaleAndLocal = "${tailscaleOnly},192.168.1.0/24,2600:1702:6250:4c80::/64";

  # Address pods use to reach services on the host. Backends must bind
  # 0.0.0.0 (not loopback) — pods cannot reach the host's 127.0.0.1.
  hostIP = config.keystone.server.tailscaleIP;

  whitelist = range: {
    "nginx.ingress.kubernetes.io/whitelist-source-range" = range;
  };

  hostServices = {
    attic = {
      host = "cache.ncrmro.com";
      port = 8199;
      annotations = whitelist tailscaleOnly // {
        "nginx.ingress.kubernetes.io/proxy-body-size" = "4G";
      };
    };
    grafana = {
      host = "grafana.ncrmro.com";
      port = 3002;
      annotations = whitelist tailscaleOnly;
    };
    journal = {
      host = "journal.ncrmro.com";
      port = 19532;
      annotations = whitelist tailscaleOnly // {
        "nginx.ingress.kubernetes.io/proxy-body-size" = "0";
        "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off";
      };
    };
    loki = {
      host = "loki.ncrmro.com";
      port = 3100;
      annotations = whitelist tailscaleOnly;
    };
    mail-admin = {
      host = "mail.ncrmro.com";
      port = 8082;
      annotations = whitelist tailscaleOnly;
    };
    mcp-grafana = {
      host = "mcp-grafana.ncrmro.com";
      port = 8090;
      annotations = whitelist tailscaleOnly // {
        "nginx.ingress.kubernetes.io/proxy-buffering" = "off";
        "nginx.ingress.kubernetes.io/proxy-read-timeout" = "86400";
      };
    };
    miniflux = {
      host = "miniflux.ncrmro.com";
      port = 8070;
      annotations = whitelist tailscaleOnly;
    };
    plouton = {
      host = "plouton.ncrmro.com";
      port = 17979;
      annotations = whitelist tailscaleOnly;
    };
    prometheus = {
      host = "prometheus.ncrmro.com";
      port = 9090;
      annotations = whitelist tailscaleOnly;
    };
    rsshub = {
      host = "rsshub.ncrmro.com";
      port = 1200;
      annotations = whitelist tailscaleOnly;
    };
    vaultwarden = {
      host = "vaultwarden.ncrmro.com";
      port = 8222;
      annotations = whitelist tailscaleOnly;
    };
    vega = {
      host = "vega.ncrmro.com";
      port = 17878;
      annotations = whitelist tailscaleOnly // {
        "nginx.ingress.kubernetes.io/proxy-buffering" = "off";
        "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off";
      };
    };

    # Jellyfin - PUBLIC (no whitelist)
    jellyfin = {
      host = "jellyfin.ncrmro.com";
      port = 8096;
    };
    radarr = {
      host = "radarr.ncrmro.com";
      port = 7878;
      annotations = whitelist tailscaleOnly;
    };
    sonarr = {
      host = "sonarr.ncrmro.com";
      port = 8989;
      annotations = whitelist tailscaleOnly;
    };
    prowlarr = {
      host = "prowlarr.ncrmro.com";
      port = 9696;
      annotations = whitelist tailscaleOnly;
    };
    bazarr = {
      host = "bazarr.ncrmro.com";
      port = 6767;
      annotations = whitelist tailscaleOnly;
    };
    lidarr = {
      host = "lidarr.ncrmro.com";
      port = 8686;
      annotations = whitelist tailscaleOnly;
    };
    readarr = {
      host = "readarr.ncrmro.com";
      port = 8787;
      annotations = whitelist tailscaleOnly;
    };
    jellyseerr = {
      host = "jellyseerr.ncrmro.com";
      port = 5055;
      annotations = whitelist tailscaleOnly;
    };
    transmission = {
      host = "transmission.ncrmro.com";
      port = 9091;
      annotations = whitelist tailscaleOnly;
    };
    sabnzbd = {
      host = "sabnzbd.ncrmro.com";
      port = 8085;
      annotations = whitelist tailscaleOnly;
    };
    home-assistant = {
      host = "home.ncrmro.com";
      port = 8123;
      annotations = whitelist tailscaleOnly;
    };
    # AdGuard - Tailscale and local network
    adguard-home = {
      host = "adguard.home.ncrmro.com";
      port = 3000;
      annotations = whitelist tailscaleAndLocal;
    };
    immich = {
      host = "photos.ncrmro.com";
      port = 2283;
      annotations = whitelist tailscaleOnly // {
        "nginx.ingress.kubernetes.io/proxy-body-size" = "50G";
      };
    };
    forgejo = {
      host = "git.ncrmro.com";
      port = 3001;
      annotations = whitelist tailscaleOnly // {
        # Container Registry pushes upload large OCI layer blobs; leave size
        # enforcement to Forgejo/storage quotas and stream instead of buffering.
        "nginx.ingress.kubernetes.io/proxy-body-size" = "0";
        "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off";
        "nginx.ingress.kubernetes.io/proxy-buffering" = "off";
      };
    };
  };

  mkManifest =
    name: svc:
    lib.nameValuePair "host-service-${name}" {
      target = "host-service-${name}.yaml";
      content = [
        {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "host-${name}";
            namespace = "default";
          };
          spec.ports = [
            {
              name = "http";
              port = svc.port;
              targetPort = svc.port;
            }
          ];
        }
        # Selector-less Service: endpoints point at the host itself
        {
          apiVersion = "v1";
          kind = "Endpoints";
          metadata = {
            name = "host-${name}";
            namespace = "default";
          };
          subsets = [
            {
              addresses = [ { ip = hostIP; } ];
              ports = [
                {
                  name = "http";
                  port = svc.port;
                }
              ];
            }
          ];
        }
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "Ingress";
          metadata = {
            name = "host-${name}";
            namespace = "default";
            annotations = svc.annotations or { };
          };
          spec = {
            ingressClassName = "nginx";
            rules = [
              {
                host = svc.host;
                http.paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend.service = {
                      name = "host-${name}";
                      port.number = svc.port;
                    };
                  }
                ];
              }
            ];
          };
        }
      ];
    };
in
{
  services.k3s.manifests = lib.mapAttrs' mkManifest hostServices;
}
