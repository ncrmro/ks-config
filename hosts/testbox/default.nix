{
  inputs,
  outputs,
  modulesPath,
  lib,
  pkgs,
  ...
}@args:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.default
    inputs.keystone.nixosModules.desktop
    # Legacy disk-config: uses disko disk name "disk1". Do NOT migrate to
    # keystone.os.storage without re-partitioning — see ncrmro-laptop boot
    # failure caused by disk1→disk0 partition label mismatch.
    ./disk-config.nix
    ./hardware-configuration.nix
    ../common/global
    ../../modules/users/ncrmro.nix
    ../../modules/users/root.nix
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit inputs outputs; };
  home-manager.users.ncrmro = import ../../home-manager/ncrmro;

  boot.initrd.systemd.emergencyAccess = false;

  keystone.desktop = {
    enable = true;
    user = "ncrmro";
  };

  networking.hostId = "5cbe3b03";
  system.stateVersion = "25.05";
}
