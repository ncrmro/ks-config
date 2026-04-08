{ inputs, oceanConfig, ... }:
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
  keystone.os.users.ncrmro.sshAutoLoad.enable = false;
}
