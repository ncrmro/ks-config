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
    ../common/optional/home-manager-base.nix
    ../../modules/keystone.nix
    ../../modules/keystone.desktop.nix
    ./disk-config.nix
    ../common/optional/zfs.luks.root.nix
    ./hardware-configuration.nix
    ../common/global
    ../common/optional/eternal-terminal.nix
    ../common/optional/nfs-client.nix
    ../common/optional/monitoring-client.nix
    ../common/optional/alloy-client.nix
    ../common/optional/zfs.backup.nix
    outputs.nixosModules.bambu-studio
    ./windows11-vm.nix
    ../../modules/nixos/steam.nix
  ];

  # Agenix secrets for agent-drago (decrypted on workstation host)
  age.secrets.agent-drago-mail-password = {
    file = "${inputs.agenix-secrets}/secrets/agent-drago-mail-password.age";
    owner = "agent-drago";
    mode = "0400";
  };
  age.secrets.agent-drago-tailscale-auth-key = {
    file = "${inputs.agenix-secrets}/secrets/agent-drago-tailscale-auth-key.age";
    owner = "agent-drago";
    mode = "0400";
  };
  age.secrets.agent-drago-ssh-key = {
    file = "${inputs.agenix-secrets}/secrets/agent-drago-ssh-key.age";
    owner = "agent-drago";
    mode = "0400";
  };
  age.secrets.agent-drago-ssh-passphrase = {
    file = "${inputs.agenix-secrets}/secrets/agent-drago-ssh-passphrase.age";
    owner = "agent-drago";
    mode = "0400";
  };
  age.secrets.agent-drago-bitwarden-password = {
    file = "${inputs.agenix-secrets}/secrets/agent-drago-bitwarden-password.age";
    owner = "agent-drago";
    mode = "0400";
  };

  keystone.os.hypervisor.connections = [ "qemu+ssh://ncrmro@ocean/session" ];
  keystone.os.hypervisor.allowedBridges = [
    "virbr0"
    "br0"
  ];

  keystone.os.services.airplay = {
    enable = true;
    name = "Workstation Speakers";
  };

  keystone.desktop.obs.gpuType = "amd";

  keystone.os.services.ollama = {
    enable = true;
    acceleration = "vulkan";
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "64000";
    models = [ "qwen3:32b" ];
  };

  # Attic push configuration (tokenFile defaults to /run/agenix/attic-push-token)
  keystone.binaryCache.push.enable = true;

  # Attic push token
  age.secrets.attic-push-token = {
    file = "${inputs.agenix-secrets}/secrets/attic-push-token.age";
  };

  programs.bambu-studio.enable = true;

  users.users.ncrmro.extraGroups = [
    "render"
    "video"
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

  # GitHub agents token
  age.secrets.github-agents-token = {
    file = "${inputs.agenix-secrets}/secrets/github-agents-token.age";
    owner = "ncrmro";
    mode = "0400";
  };

  # Per-host home-manager config: monitor layout, rebuild target, host-specific packages
  home-manager.users.ncrmro = import ../../home-manager/ncrmro/ncrmro-workstation.nix;

  environment.systemPackages = with pkgs; [
    alsa-utils
    lsof
    amdgpu_top
    lutris
    # llama-cpp from upstream flake with Vulkan support for AMD GPU acceleration
    inputs.llama-cpp.packages.${pkgs.stdenv.hostPlatform.system}.vulkan
  ];

  environment.variables = {
    TERM = "xterm-256color"; # Or your preferred terminal type
  };
  programs.nix-ld.enable = true;

  hardware.keyboard.uhk.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.openssh.settings.PermitRootLogin = "yes";

  # OOM Killer configuration
  # Prioritize killing docker/podman rootless processes over Hyprland
  # NOTE: Cannot set OOMScoreAdjust for wayland-wm@Hyprland because NixOS creates
  # a replacement unit instead of a drop-in, breaking the UWSM template service.
  systemd.user.services = {
    docker.serviceConfig.OOMScoreAdjust = 1000;
    podman.serviceConfig.OOMScoreAdjust = 1000;
  };

  services.monitoring-client = {
    enable = true;
  };

  services.alloy-client = {
    enable = true;
    enableZfsExporter = true;
    extraLabels = {
      environment = "home";
      device_type = "workstation";
    };
  };

  # Disable HDA Intel audio (GPU HDMI + onboard) - keep only USB audio devices
  # This may help with Hyprland crashes caused by snd_hda_intel spurious responses
  boot.blacklistedKernelModules = [ "snd_hda_intel" ];

  # Enable aarch64 emulation for cross-compilation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Increase inotify limits for file watchers (IDEs, build tools, etc.)
  # Each watch uses ~1KB kernel memory. Rule of thumb: 1M watches per 16GB RAM.
  # 10M watches ≈ 10GB kernel memory - suitable for 32GB+ systems.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 10485760;
    "fs.inotify.max_user_instances" = 8192;
  };

  # Bridge networking: br0 enslaves enp5s0 so VMs can get LAN IPs directly
  networking.useDHCP = false;
  networking.hostId = "cb1216ed"; # generate with: head -c 8 /etc/machine-id
  networking.hostName = "ncrmro-workstation";

  networking.bridges.br0.interfaces = [ "enp5s0" ];

  networking.interfaces.enp5s0 = { };

  networking.interfaces.br0 = {
    ipv4.addresses = [
      {
        address = "192.168.1.69";
        prefixLength = 24;
      }
    ];
    ipv6.addresses = [
      {
        address = "2600:1702:6250:4c80::69";
        prefixLength = 64;
      }
    ];
  };

  networking.defaultGateway = {
    address = "192.168.1.254";
    #interface = "br0";
  };

  networking.defaultGateway6 = {
    address = "2600:1702:6250:4c80::1";
    #    interface = "br0";
  };
  # needed for remote building I think nix --builders
  nix.settings.trusted-users = [
    "root"
    "ncrmro"
  ];
  networking.nameservers = [
    # Local DNS on ocean (DHCP/DNS host)
    "192.168.1.10"
    "2600:1702:6250:4c80:da5e:d3ff:fe8e:3126"
    # Uncommit if local server goes down
    # "1.1.1.1"
  ];

  system.stateVersion = "25.11";
}
