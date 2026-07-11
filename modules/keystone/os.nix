# All-hosts NixOS base — merges modules/keystone.nix + hosts/common/global/default.nix.
# Every machine in the fleet imports this module.
{
  config,
  inputs,
  lib,
  ...
}:
{
  # `keystone.nixosModules.operating-system` is imported automatically by
  # mkSystemFlake (via mkLinuxHost). Re-importing it here from
  # `inputs.keystone.nixosModules.operating-system` produces a second
  # _file-less inline-attrset module instance that NixOS does not
  # deduplicate; sharedModules entries get applied twice and trigger
  # `_module.args.keystoneInputs` "defined multiple times" errors.
  #
  # `keystone.nixosModules.{domain,services,hosts}` are already pulled in
  # by `operating-system`'s own imports list (see keystone flake.nix), so
  # they don't need to be repeated either.
  imports = [
    inputs.keystone.nixosModules.hardwareKey
    inputs.keystone.nixosModules.keys
    inputs.keystone.nixosModules.binaryCacheClient
    ../keys.nix
    ../../hosts/common/global/openssh.nix
    ../../hosts/common/agent-identities.nix
    ./os/agents/auto-secrets.nix
  ];

  # Fleet-wide identity
  keystone.domain = "ncrmro.com";
  keystone.headscaleDomain = "mercury";
  keystone.services = {
    mail.host = "ocean";
    git.host = "ocean";
    immich.host = "ocean";
    immich.workers = [ "ncrmro-workstation" ];
    notesDaily.host = "ocean";
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

  environment.variables = {
    KEYSTONE_CURRENT_HOST = config.networking.hostName;
    KEYSTONE_FLEET_DOMAIN = config.keystone.domain;
  };

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
    # mkSystemFlake templates disable Tailscale by default because generic
    # consumers may not provide a hosts registry. This fleet always sets
    # keystone.hosts below, so keep the historical "all keystone OS hosts join
    # Headscale unless a host explicitly opts out" behavior.
    tailscale.enable = true;
    ssh.enable = lib.mkDefault false; # SSH configured independently
    hypervisor.enable = lib.mkDefault true;
    # The admin user (ncrmro) is now declared in flake.nix `adminUser` and
    # threaded through `mkSystemFlake { admin = ...; }`. Keep per-host
    # tweaks (e.g. desktop.enable on workstation/laptop) in their own modules;
    # do not redeclare the admin user here.
    #
    # Supplementary groups are module-owned post-#470/#471:
    #   wheel, podman, libvirtd, dialout, media → admin (this user)
    #   networkmanager, video, audio           → desktop users (via desktop.enable)
    #   zfs                                    → all users on ZFS storage
    # Retired groups: input, sound, docker (see keystone process.user-groups).
  };

  keystone.secrets.repo = inputs.agenix-secrets;
}
