# Maia - Legacy home server
#
# Secure Boot via keystone operating-system module (Lanzaboote + sbctl).
# User management via keystone.nix (ncrmro user + root keys via hardwareKey).
# Disko partitioning provided by keystone operating-system module.
{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../common/optional/zfs.luks.root.nix
    ./zpool.lake.noblock.nix
    ../common/optional/zfs.backup.nix
    ../common/global
    ../common/optional/alloy-client.nix
    ../common/optional/monitoring-client.nix
    ../../modules/keystone.nix
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
