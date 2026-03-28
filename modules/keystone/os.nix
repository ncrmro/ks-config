# All-hosts NixOS base — merges modules/keystone.nix + hosts/common/global/default.nix.
# Every machine in the fleet imports this module.
{ inputs, lib, ... }:
{
  imports = [
    inputs.keystone.nixosModules.operating-system
    inputs.keystone.nixosModules.hardwareKey
    inputs.keystone.nixosModules.keys
    inputs.keystone.nixosModules.binaryCacheClient
    inputs.keystone.nixosModules.domain
    inputs.keystone.nixosModules.services
    inputs.keystone.nixosModules.hosts
    ../keys.nix
    ../users/root.nix
    ../../hosts/common/global/openssh.nix
    ../../hosts/common/agent-identities.nix
  ];

  # Fleet-wide identity
  keystone.domain = "ncrmro.com";
  keystone.services = {
    mail.host = "ocean";
    git.host = "ocean";
    immich.host = "ocean";
    immich.workers = [ "ncrmro-workstation" ];
  };
  keystone.hosts = import ../../hosts.nix;

  nixpkgs.overlays = import ../../overlays { inherit inputs; };
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Attic binary cache on ocean (Tailscale-only)
  # URL auto-derived from keystone.domain → https://cache.ncrmro.com
  keystone.binaryCache = {
    enable = true;
    publicKey = "main:H852yjGdbbRIOQcnKm3uZOpZWRFmQoQ5p4I7VDz7kAI=";
  };
  time.timeZone = "America/Chicago";

  keystone.repos = import ../../repos.nix;
  keystone.development = true;

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

  keystone.secrets.repo = inputs.agenix-secrets;
}
