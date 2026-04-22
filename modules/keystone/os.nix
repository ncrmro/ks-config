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
    ../../hosts/common/global/openssh.nix
    ../../hosts/common/agent-identities.nix
  ];

  # Fleet-wide identity
  keystone.domain = "ncrmro.com";
  keystone.headscaleDomain = "mercury";
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

  # Consumer flake path — convention default is `keystone-config`, but this
  # fleet's repo is named `nixos-config`. Override to match reality.
  keystone.systemFlake.path = "/home/ncrmro/.keystone/repos/ncrmro/nixos-config";

  keystone.os = {
    enable = lib.mkDefault true;
    storage.enable = lib.mkDefault false; # All hosts use disko
    ssh.enable = lib.mkDefault false; # SSH configured independently
    hypervisor.enable = lib.mkDefault true;
    users.ncrmro = {
      admin = true;
      fullName = "Nicholas Romero";
      # Supplementary groups are module-owned post-#470/#471:
      #   wheel, podman, libvirtd, dialout, media → admin (this user)
      #   networkmanager, video, audio           → desktop users (via desktop.enable)
      #   zfs                                    → all users on ZFS storage
      # Retired groups: input, sound, docker (see keystone process.user-groups).
      terminal.enable = lib.mkDefault true;
      capabilities = [
        "ks"
        "engineer"
        "product"
        "project-manager"
        "notes"
      ];
    };
  };

  keystone.secrets.repo = inputs.agenix-secrets;
}
