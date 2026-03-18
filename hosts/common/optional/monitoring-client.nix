{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.monitoring-client;
in
{
  options.services.monitoring-client = {
    enable = lib.mkEnableOption "monitoring client with Prometheus exporters";
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1"; # Only localhost - Alloy scrapes locally
      port = 9100;
      enabledCollectors = [
        "systemd"
        "textfile"
      ];
      extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter" ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/prometheus-node-exporter 0755 root root -"
    ];
  };
}
