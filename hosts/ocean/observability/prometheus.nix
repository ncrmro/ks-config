{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.observability.prometheus;
in
{
  options.my.observability.prometheus = {
    enable = lib.mkEnableOption "Prometheus monitoring service";
    nginxExtraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration for the Nginx virtual host";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 9090;
      retentionTime = "90d";
      checkConfig = "syntax-only";

      # Enable remote write receiver for Alloy push-based metrics
      extraFlags = [ "--web.enable-remote-write-receiver" ];

      exporters = {
        node = {
          enable = true;
          enabledCollectors = [
            "systemd"
            "textfile"
          ];
          extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter" ];
          port = 9100;
        };
      };

      # ZFS backup alert rules
      rules = [
        (builtins.toJSON {
          groups = [
            {
              name = "zfs-backup";
              rules = [
                {
                  alert = "ZfsBackupStale";
                  expr = "time() - zfs_backup_last_success_timestamp > 7200";
                  "for" = "30m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "ZFS backup stale: {{ $labels.job }}";
                    description = "Backup {{ $labels.job }} ({{ $labels.source_host }}:{{ $labels.source_pool }} → {{ $labels.target_host }}:{{ $labels.target_pool }}) has not succeeded in over 2 hours.";
                  };
                }
                {
                  alert = "ZfsBackupFailed";
                  expr = "zfs_backup_last_exit_code != 0";
                  "for" = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "ZFS backup failed: {{ $labels.job }}";
                    description = "Backup {{ $labels.job }} exited with code {{ $value }}.";
                  };
                }
                {
                  alert = "ZfsSnapshotStale";
                  expr = "zfs_snapshot_newest_age_seconds > 7200";
                  "for" = "30m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "ZFS snapshots stale on {{ $labels.host }}:{{ $labels.pool }}";
                    description = "Newest snapshot on {{ $labels.host }}:{{ $labels.pool }} is {{ $value | humanizeDuration }} old.";
                  };
                }
              ];
            }
          ];
        })
      ];

      # Ocean's node exporter is already scraped by Alloy (with host/cluster labels)
      # via remote-write. Only scrape non-Alloy targets here to avoid duplicate series
      # that cause alert evaluation errors (duplicate empty-label frames).
      scrapeConfigs = [
        {
          job_name = "iot";
          static_configs = [
            {
              targets = [ "192.168.1.140:80" ];
              labels = {
                instance = "seed-incubator";
                environment = "home";
                location = "garage";
                device_type = "plant-seed-incubator";
                plants = "dill,arugula";
              };
            }
            {
              targets = [ "192.168.1.145:80" ];
              labels = {
                instance = "plant-monitor";
                environment = "home";
                device_type = "plant-monitor";
              };
            }
          ];
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter 0755 root root -"
    ];

    services.nginx.virtualHosts."prometheus.ncrmro.com" = {
      forceSSL = true;
      useACMEHost = "wildcard-ncrmro-com";
      extraConfig = cfg.nginxExtraConfig;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.prometheus.port}";
        proxyWebsockets = true;
      };
    };
  };
}
