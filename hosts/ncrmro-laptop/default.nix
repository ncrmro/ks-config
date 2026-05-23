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
    ../../modules/keystone/os.nix
    ../../modules/keystone/desktop.nix
    # outputs.nixosModules.omarchy-config
    # Legacy disk-config: uses disko disk name "disk1", producing partition
    # labels like disk-disk1-ESP and disk-disk1-encryptedSwap baked into GPT.
    # keystone.os.storage uses 0-based naming (disk0), which breaks boot on
    # existing installs because the on-disk labels don't match. Do NOT migrate
    # to keystone.os.storage without re-partitioning or adding a disk-name
    # migration path in the keystone module.
    ./disk-config.nix
    ../common/optional/zfs.luks.root.nix
    ./hardware-configuration.nix
    # ../common/optional/docker-root.nix
    ../common/optional/eternal-terminal.nix
    ../common/optional/nfs-client.nix
    ../common/optional/monitoring-client.nix
    ../common/optional/alloy-client.nix
    ../common/optional/zfs.backup.nix
    ../common/optional/ableton-live.nix
    ../../modules/nixos/steam.nix
    outputs.nixosModules.bambu-studio
  ];

  keystone.os.iphoneTether.enable = true;
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

  # GitHub agents token (user-readable; for keystone.terminal.github future opt-in)
  age.secrets.github-agents-token = {
    file = "${inputs.agenix-secrets}/secrets/github-agents-token.age";
    owner = "ncrmro";
    mode = "0400";
  };

  # GitHub token for the nix daemon (root-readable, for /etc/nix/access-tokens.conf)
  age.secrets.nix-github-token = {
    file = "${inputs.agenix-secrets}/secrets/nix-github-token.age";
    owner = "root";
    mode = "0400";
  };
  keystone.os.githubTokenNix.enable = true;

  # Grafana API token for MCP and dashboards
  age.secrets.grafana-api-token = {
    file = "${inputs.agenix-secrets}/secrets/grafana-api-token.age";
    owner = "ncrmro";
    mode = "0400";
  };

  # User-home Immich API key for Home Manager shell access
  age.secrets.ncrmro-immich-api-key = {
    file = "${inputs.agenix-secrets}/secrets/ncrmro-immich-api-key.age";
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
