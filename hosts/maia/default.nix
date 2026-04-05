# Maia - Legacy home server
#
# Secure Boot via keystone operating-system module (Lanzaboote + sbctl).
# User management via modules/keystone/os.nix (ncrmro user + root keys via hardwareKey).
# Disko partitioning provided by keystone operating-system module.
{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    # Legacy disk-config: uses disko disk name "disk1", producing partition
    # labels like disk-disk1-ESP and disk-disk1-encryptedSwap baked into GPT.
    # keystone.os.storage uses 0-based naming (disk0), which breaks boot on
    # existing installs because the on-disk labels don't match. Do NOT migrate
    # to keystone.os.storage without re-partitioning or adding a disk-name
    # migration path in the keystone module.
    ./disk-config.nix
    ../common/optional/zfs.luks.root.nix
    ./zpool.lake.noblock.nix
    ../common/optional/zfs.backup.nix
    ../../modules/keystone/os.nix
    ../common/optional/alloy-client.nix
    ../common/optional/monitoring-client.nix
  ];

  # ZFS backup: maia is a receiver only — pool import dep for lake
  my.zfs.backup.poolImportServices.lake = "import-lake";

  boot.initrd.systemd.emergencyAccess = false;

  environment.systemPackages = [
    pkgs.htop
    pkgs.usbutils
    pkgs.btop
  ];

  environment.variables = {
    TERM = "xterm-256color"; # Or your preferred terminal type
  };

  # Ship logs and metrics to ocean via Alloy
  services.monitoring-client.enable = true;
  services.alloy-client = {
    enable = true;
    enableZfsExporter = true;
    extraLabels = {
      environment = "production";
      device_type = "server";
    };
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  services.openssh.settings.PermitRootLogin = "yes";

  networking.hostId = "22386ca6"; # generate with: head -c 8 /etc/machine-id
  networking.hostName = "maia"; # Define your hostname.

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
