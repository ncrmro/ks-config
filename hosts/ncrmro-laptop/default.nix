{
  config,
  inputs,
  outputs,
  modulesPath,
  lib,
  pkgs,
  ...
}@args:
{
  imports = [
    # lanzaboote provided by keystone operating-system module
    # inputs.omarchy-nix.nixosModules.default
    ../common/optional/home-manager-base.nix
    ../../modules/keystone.nix
    ../../modules/keystone.desktop.nix
    # outputs.nixosModules.omarchy-config
    ./disk-config.nix
    ../common/optional/zfs.luks.root.nix
    ./hardware-configuration.nix
    ../common/global
    # ../common/optional/docker-root.nix
    ../common/optional/eternal-terminal.nix
    ../common/optional/nfs-client.nix
    ../common/optional/monitoring-client.nix
    ../common/optional/alloy-client.nix
    ../common/optional/zfs.backup.nix
    ../../modules/nixos/steam.nix
    outputs.nixosModules.bambu-studio
  ];

  keystone.os.hypervisor.connections = [
    "qemu+ssh://ncrmro@ocean/session"
    "qemu+ssh://ncrmro@ncrmro-workstation/session"
  ];

  # Stalwart mail user password for himalaya
  age.secrets.stalwart-mail-ncrmro-password = {
    file = "${inputs.agenix-secrets}/secrets/stalwart-mail-ncrmro-password.age";
    owner = "ncrmro";
    mode = "0400";
  };

  # Cliflux config (Miniflux CLI client)
  age.secrets.cliflux-config = {
    file = "${inputs.agenix-secrets}/secrets/cliflux-config.age";
    owner = "ncrmro";
    mode = "0400";
  };

  # Attic push configuration (tokenFile defaults to /run/agenix/attic-push-token)
  keystone.binaryCache.push.enable = true;

  # Attic push token
  age.secrets.attic-push-token = {
    file = "${inputs.agenix-secrets}/secrets/attic-push-token.age";
  };

  # GitHub agents token
  age.secrets.github-agents-token = {
    # Grafana API token for MCP and dashboards
    age.secrets.grafana-api-token = {
      file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
      owner = "ncrmro";
      mode = "0400";
    };
    file = "${inputs.agenix-secrets}/secrets/github-agents-token.age";
    # Grafana API token for MCP and dashboards
    age.secrets.grafana-api-token = {
      file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
      owner = "ncrmro";
      mode = "0400";
    };
    owner = "ncrmro";
    # Grafana API token for MCP and dashboards
    age.secrets.grafana-api-token = {
      file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
      owner = "ncrmro";
      mode = "0400";
    };
    mode = "0400";
    # Grafana API token for MCP and dashboards
    age.secrets.grafana-api-token = {
      file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
      owner = "ncrmro";
      mode = "0400";
    };
  };
  # Grafana API token for MCP and dashboards
  age.secrets.grafana-api-token = {
    file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
    owner = "ncrmro";
    mode = "0400";
  };

  programs.bambu-studio.enable = true;

  # Per-host home-manager config: monitor layout, rebuild target
  home-manager.users.ncrmro = import ../../home-manager/ncrmro/ncrmro-laptop.nix;

  # services.greetd = {
  #   enable = true;
  #   settings.default_session.user = "ncrmro";
  # };

  # iOS USB tethering/hotspot
  keystone.os.iphoneTether.enable = true;

  keystone.desktop.obs.gpuType = "amd";

  services.hardware.bolt.enable = true;
  services.fwupd.enable = true;
  services.gnome.gnome-keyring.enable = true;
  # security.pam.services.greetd.enableGnomeKeyring = true;

  # Allow unfree packages like VSCode
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    pkgs.nfs-utils
    pkgs.nvtopPackages.amd
    # inputs.alejandra.defaultPackage."x86_64-linux"
  ];

  programs.nix-ld.enable = true;

  keystone.hardware.uhk.enable = true;

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };
  services.fprintd.enable = true;

  # networking.firewall.enable = true;
  # networking.firewall.logRefusedConnections = true;

  services.monitoring-client = {
    enable = true;
  };

  services.alloy-client = {
    enable = true;
    extraLabels = {
      environment = "home";
      device_type = "laptop";
    };
  };

  networking.hostName = "ncrmro-laptop";
  networking.hostId = "cac44b47";
  system.stateVersion = "25.11";
}
