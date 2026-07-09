{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # Secret for AdGuard admin password hash
  age.secrets.adguard-password-hash = {
    file = "${inputs.agenix-secrets}/secrets/adguard-password-hash.age";
    owner = "root";
    mode = "0400";
  };

  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    openFirewall = false;
    allowDHCP = true;

    settings = {
      http = {
        pprof = {
          port = 6060;
          enabled = false;
        };
        # Bind all interfaces: reached from k8s ingress pods via the node
        # address (firewall stays closed to LAN; only cni0 is trusted).
        address = "0.0.0.0:3000";
        session_ttl = "720h";
      };

      # Users are injected at runtime via systemd preStart
      users = [
        # Leaving this here, to document that this is what agenix merge sets
        #   {
        #   name = "ncrmro";
        #   password =
        #     "$2y$10$....";
        # }

      ];

      auth_attempts = 5;
      block_auth_min = 15;
      theme = "auto";

      dns = {
        bind_hosts = [
          "0.0.0.0"
          "::"
        ];
        port = 53;
        anonymize_client_ip = false;
        ratelimit = 200;
        ratelimit_subnet_len_ipv4 = 24;
        ratelimit_subnet_len_ipv6 = 56;
        refuse_any = true;

        upstream_dns = [
          "https://family.cloudflare-dns.com/dns-query"
          "https://dns.google/dns-query"
          "https://dns11.quad9.net/dns-query"
          "https://security.cloudflare-dns.com/dns-query"
          "h3://unfiltered.adguard-dns.com/dns-query"
          "h3://doh.ffmuc.net/dns-query"
        ];

        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
          "2620:fe::10"
          "2620:fe::fe:10"
        ];

        fallback_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        upstream_mode = "load_balance";
        fastest_timeout = "1s";

        blocked_hosts = [
          "version.bind"
          "id.server"
          "hostname.bind"
        ];

        trusted_proxies = [
          "127.0.0.0/8"
          "::1/128"
          # k8s ingress-nginx pods (real client IP arrives via X-Forwarded-For)
          "10.42.0.0/16"
        ];

        cache_size = 4194304;
        cache_ttl_min = 0;
        cache_ttl_max = 0;
        cache_optimistic = false;
        aaaa_disabled = false;
        enable_dnssec = true;

        edns_client_subnet = {
          enabled = true;
          use_custom = false;
        };

        max_goroutines = 300;
        handle_ddr = true;
        bootstrap_prefer_ipv6 = false;
        upstream_timeout = "1s";
        use_private_ptr_resolvers = true;
        use_dns64 = false;
        serve_http3 = false;
        use_http3_upstreams = false;
        serve_plain_dns = true;
        hostsfile_enabled = true;
      };

      tls = {
        enabled = false;
        force_https = false;
        port_https = 443;
        port_dns_over_tls = 853;
        port_dns_over_quic = 853;
        port_dnscrypt = 0;
        allow_unencrypted_doh = false;
        strict_sni_check = false;
      };

      querylog = {
        ignored = [ ];
        interval = "2160h";
        size_memory = 1000;
        enabled = true;
        file_enabled = true;
      };

      statistics = {
        ignored = [ ];
        interval = "2160h";
        enabled = true;
      };

      filters = [
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }
        {
          enabled = false;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          name = "AdAway Default Blocklist";
          id = 2;
        }
      ];

      dhcp = {
        enabled = true;
        interface_name = "enp4s0";
        local_domain_name = "lan";
        dhcpv4 = {
          gateway_ip = "192.168.1.254";
          subnet_mask = "255.255.255.0";
          range_start = "192.168.1.100";
          range_end = "192.168.1.200";
          lease_duration = 86400;
          icmp_timeout_msec = 1000;
        };
        dhcpv6 = {
          range_start = "2001::1";
          lease_duration = 86400;
          ra_slaac_only = false;
          ra_allow_slaac = false;
        };
      };

      filtering = {
        blocked_services = {
          schedule.time_zone = "Local";
          ids = [ ];
        };
        safe_search = {
          enabled = false;
          bing = true;
          duckduckgo = true;
          ecosia = true;
          google = true;
          pixabay = true;
          yandex = true;
          youtube = true;
        };
        blocking_mode = "default";
        parental_block_host = "family-block.dns.adguard.com";
        safebrowsing_block_host = "standard-block.dns.adguard.com";
        rewrites = [
          {
            domain = "ingress.home.ncrmro.com";
            answer = "192.168.1.10";
          }
          {
            domain = "jellyfin.ncrmro.com";
            answer = "ingress.home.ncrmro.com";
          }
          {
            domain = "adguard.home.ncrmro.com";
            answer = "ingress.home.ncrmro.com";
          }
          {
            domain = "grafana.ncrmro.com";
            answer = "ingress.home.ncrmro.com";
          }
          {
            domain = "prometheus.ncrmro.com";
            answer = "ingress.home.ncrmro.com";
          }
          {
            domain = "loki.ncrmro.com";
            answer = "ingress.home.ncrmro.com";
          }
        ];
        safebrowsing_cache_size = 1048576;
        safesearch_cache_size = 1048576;
        parental_cache_size = 1048576;
        cache_time = 30;
        filters_update_interval = 24;
        blocked_response_ttl = 10;
        filtering_enabled = true;
        parental_enabled = false;
        safebrowsing_enabled = false;
        protection_enabled = true;
      };

      clients = {
        runtime_sources = {
          whois = true;
          arp = true;
          rdns = true;
          dhcp = true;
          hosts = true;
        };
        persistent = [ ];
      };

      log = {
        enabled = true;
        max_backups = 0;
        max_size = 100;
        max_age = 3;
        compress = false;
        local_time = false;
        verbose = false;
      };

      schema_version = 29;
    };
  };

  # Open firewall for DNS and DHCP on all interfaces (ocean is the main DNS/DHCP server)
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [
      53
      67
      68
    ];
  };

  # Inject the password hash from agenix secret at runtime using ExecStartPre running as root
  systemd.services.adguardhome.serviceConfig.ExecStartPre = lib.mkAfter [
    (
      "+"
      + (pkgs.writeShellScript "inject-adguard-password" ''
        echo "Running injection script as user: $(whoami) (id: $(id -u))"
        ls -l /run/agenix/adguard-password-hash

        configPath="/var/lib/AdGuardHome/AdGuardHome.yaml"

        # Wait for config file to be written by the NixOS module's preStart script
        # This script runs after the main preStart because of lib.mkAfter

        if [ -f "$configPath" ]; then
          # Read password hash from secret and inject into config
          PASSWORD_HASH=$(cat ${config.age.secrets.adguard-password-hash.path})
          
          # Use yq to update the users array with the password hash
          ${pkgs.yq-go}/bin/yq -i '.users = [{"name": "ncrmro", "password": "'"$PASSWORD_HASH"'"}]' "$configPath"
        fi
      '')
    )
  ];
}
