# Manual vhosts for non-keystone services.
# ACME, base nginx, and firewall are managed by keystone.server.acme + keystone nginx module.
{ ... }:
let
  k8sIngressHttp = "127.0.0.1:8080";
  # Allow/deny config for Tailscale-only services
  tailscaleOnly = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
  # Allow Tailscale and local network
  tailscaleAndLocal = ''
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    allow 192.168.1.0/24;
    allow 2600:1702:6250:4c80::/64;
    deny all;
  '';
in
{
  # Jellyfin - PUBLIC (no access restriction)
  services.nginx.virtualHosts."jellyfin.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;
    };
  };

  # Personal Website - PUBLIC (proxied to k8s)
  services.nginx.virtualHosts."ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    locations."/" = {
      proxyPass = "http://${k8sIngressHttp}";
      proxyWebsockets = true;
    };
  };

  # Radarr - Tailscale only
  services.nginx.virtualHosts."radarr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:7878";
      proxyWebsockets = true;
    };
  };

  # Sonarr - Tailscale only
  services.nginx.virtualHosts."sonarr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8989";
      proxyWebsockets = true;
    };
  };

  # Prowlarr - Tailscale only
  services.nginx.virtualHosts."prowlarr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:9696";
      proxyWebsockets = true;
    };
  };

  # Bazarr - Tailscale only
  services.nginx.virtualHosts."bazarr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:6767";
      proxyWebsockets = true;
    };
  };

  # Lidarr - Tailscale only
  services.nginx.virtualHosts."lidarr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8686";
      proxyWebsockets = true;
    };
  };

  # Readarr - Tailscale only
  services.nginx.virtualHosts."readarr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8787";
      proxyWebsockets = true;
    };
  };

  # Jellyseerr - Tailscale only
  services.nginx.virtualHosts."jellyseerr.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:5055";
      proxyWebsockets = true;
    };
  };

  # Transmission - Tailscale only
  services.nginx.virtualHosts."transmission.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:9091";
      proxyWebsockets = true;
    };
  };

  # SABnzbd - Tailscale only
  services.nginx.virtualHosts."sabnzbd.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8085";
      proxyWebsockets = true;
    };
  };

  # Home Assistant - Tailscale only
  services.nginx.virtualHosts."home.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
    };
  };

  # AdGuard Home - Tailscale and local network
  services.nginx.virtualHosts."adguard.home.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleAndLocal;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true;
    };
  };

  # Immich - Tailscale only
  services.nginx.virtualHosts."photos.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = ''
      ${tailscaleOnly}
      client_max_body_size 50G;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
    };
  };

  services.nginx.virtualHosts."git.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3001";
      proxyWebsockets = true;
    };
  };

  services.nginx.virtualHosts."longhorn.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://${k8sIngressHttp}";
      proxyWebsockets = true;
    };
  };

  # Stalwart Mail - Tailscale only
  # Single HTTP listener on :8082 serves the admin web UI, the REST
  # management API, JMAP, CalDAV (/dav/cal), CardDAV (/dav/card), WebDAV
  # (/dav/file), and the DAV bootstrap endpoints (/.well-known/{caldav,carddav}).
  # The catch-all "/" location already proxies every path to upstream; the
  # explicit /dav/ and /.well-known/* blocks below exist so an operator
  # auditing the vhost can see at a glance which DAV surface is exposed
  # and so DAV-specific tweaks (e.g. larger client_max_body_size for big
  # vCard imports) have an obvious home.
  services.nginx.virtualHosts."mail.ncrmro.com" = {
    forceSSL = true;
    useACMEHost = "wildcard-ncrmro-com";
    extraConfig = tailscaleOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8082";
      proxyWebsockets = true;
    };
    # CalDAV bootstrap — clients hit this first for principal discovery.
    locations."/.well-known/caldav" = {
      proxyPass = "http://127.0.0.1:8082";
    };
    # CardDAV bootstrap — same role for address books.
    locations."/.well-known/carddav" = {
      proxyPass = "http://127.0.0.1:8082";
    };
    # All DAV collections live under /dav/{cal,card,file,pal,itip}/.
    # Raise body size so calendar/address-book imports (full ICS/VCF
    # dumps from existing clients) aren't truncated by nginx's 1m default.
    locations."/dav/" = {
      proxyPass = "http://127.0.0.1:8082";
      extraConfig = ''
        client_max_body_size 50M;
      '';
    };
  };
}
