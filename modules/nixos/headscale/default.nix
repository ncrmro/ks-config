# Headscale configuration module
{
  config,
  lib,
  ...
}:
let
  domain = "mercury.ncrmro.com";
in
{
  # Configure ACME for SSL certificates
  security.acme = {
    acceptTerms = true;
    defaults.email = "ncrmro@gmail.com";
  };

  # Enable nginx for reverse proxy
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
  };

  # Open firewall ports for HTTP/HTTPS, headscale, and DERP
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      8080
    ];
    allowedUDPPorts = [ 3478 ];
  };

  services = {
    headscale = {
      enable = true;
      address = "0.0.0.0";
      port = 8080;
      settings = {
        logtail.enabled = false;
        server_url = "https://${domain}";
        dns = {
          base_domain = "mercury";
          magic_dns = true;
          nameservers = {
            # Use AdGuard Home instances for DNS with ad-blocking
            # 100.64.0.38 = mercury (primary), 100.64.0.6 = ocean (secondary)
            global = [
              "100.64.0.6"
              "100.64.0.38"
            ];
          };
          override_local_dns = true;
          extra_records = [
            {
              name = "adguard.ncrmro.com";
              type = "A";
              value = "100.64.0.38";
            }
            {
              name = "adguard.mercury.ncrmro.com";
              type = "A";
              value = "100.64.0.38";
            }
            {
              name = "grafana.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "prometheus.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "vaultwarden.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "loki.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "adguard.home.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            # Home Assistant ingress - kept in sync with:
            # - /hosts/common/kubernetes/home-assistant.nix
            {
              name = "home.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "longhorn.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "jellyfin.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "radarr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "sonarr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "prowlarr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "bazarr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "lidarr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "readarr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "jellyseerr.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "transmission.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "sabnzbd.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "git.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "rsshub.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "miniflux.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "mail.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "mcp-grafana.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "photos.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "harmonia.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
            {
              name = "journal.ncrmro.com";
              type = "A";
              value = "100.64.0.6";
            }
          ];
        };
        derp = {
          server = {
            enabled = true;
            region_id = 999;
            region_code = "mercury";
            region_name = "Mercury DERP";
            stun_listen_addr = "0.0.0.0:3478";
          };
        };
        policy = {
          path = "/etc/headscale/acl.hujson";
        };
      };
    };

    nginx.virtualHosts.${domain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.headscale.port}";
        proxyWebsockets = true;
      };
    };
  };

  environment.systemPackages = [ config.services.headscale.package ];

  # Copy ACL configuration to system
  environment.etc."headscale/acl.hujson".source = ./acl.hujson;
}
