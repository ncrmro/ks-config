{ inputs, lib, ... }:
{
  imports = [
    inputs.keystone.nixosModules.operating-system
    inputs.keystone.nixosModules.hardwareKey
    ./keys.nix
    ../hosts/common/agent-identities.nix
  ];

  keystone.repos = import ../repos.nix;

  keystone.hardwareKey = {
    enable = lib.mkDefault true;
    rootKeys = [
      "ncrmro/yubi-black"
      "ncrmro/yubi-green"
    ];
    gpgAgent = {
      enable = lib.mkDefault false;
      enableSSHSupport = lib.mkDefault false;
    };
  };

  keystone.os = {
    enable = lib.mkDefault true;
    storage.enable = lib.mkDefault false; # All hosts use disko
    ssh.enable = lib.mkDefault false; # SSH configured independently
    hypervisor.enable = lib.mkDefault true;

    users.ncrmro = {
      fullName = "Nicholas Romero";
      extraGroups = [
        "wheel"
        "media"
        "audio"
        "input"
        "networkmanager"
        "sound"
        "docker"
        "podman"
        "dialout"
      ];
      terminal.enable = lib.mkDefault true;
      sshAutoLoad.enable = lib.mkDefault true;
    };
  };

  keystone.development = true;

  keystone.services = {
    mail.host = "ocean";
    git.host = "ocean";
    immich.host = "ocean";
    immich.workers = [ "ncrmro-workstation" ];
  };

  keystone.secrets.repo = inputs.agenix-secrets;
}
