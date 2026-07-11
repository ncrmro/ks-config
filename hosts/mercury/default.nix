{ inputs, lib, oceanConfig, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/headscale
    ../../modules/keystone/os.nix
    ../common/optional/alloy-client.nix
    ./adguard-home.nix
    ./nginx.nix
    inputs.keystone.nixosModules.headscale-dns
    inputs.keystone.nixosModules.headscale-acl
  ];

  # Mercury is a Vultr VPS that boots via grub-in-ESP, not systemd-boot.
  # keystone's mkLinuxHost defaults `boot.loader.systemd-boot.enable = true`
  # via mkDefault — that's fine for baremetal UEFI hosts but wrong here:
  # the activation step runs `bootctl install`, finds no systemd-boot in
  # the ESP, and aborts the switch. Force systemd-boot off and let grub
  # (already declared in hardware-configuration.nix) handle the ESP.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = true;

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  time.timeZone = "America/Chicago";
  networking.hostName = "mercury";
  networking.domain = "";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  services.alloy-client = {
    enable = true;
    extraLabels = {
      environment = "production";
      device_type = "vps";
      service = "headscale";
    };
  };

  # Auto-DNS and ACL: import generated records from ocean's keystone services
  keystone.headscale = {
    enable = true;
    dnsRecords = oceanConfig.keystone.server.generatedDNSRecords;
    aclRules = oceanConfig.keystone.services.generatedACLRules;
    generatedTagOwners = oceanConfig.keystone.services.generatedTagOwners;
  };

  system.stateVersion = "25.05";

  # Opt-outs for mercury (VPS environment)
  keystone.hardwareKey.enable = false;
  keystone.os.secureBoot.enable = false;
  keystone.os.tpm.enable = false;
  keystone.os.hypervisor.enable = false;
  # mkForce: the server kind applies flake.nix's adminUser (sshAutoLoad on)
  # at normal priority; server-vm applied it via mkDefault, so this opt-out
  # needs forcing since the revert back to kind = "server".
  keystone.os.users.ncrmro.sshAutoLoad.enable = lib.mkForce false;
  # No local-link peers on a public-internet VPS — avahi would advertise
  # on the public network without serving any fleet purpose.
  keystone.os.services.avahi.enable = false;
}
