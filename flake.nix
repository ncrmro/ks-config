{
  description = "ncrmro's fleet — keystone-systems shared config (keystone.yaml is the source of truth)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Fleet harness from keystone-systems/os main (REQ-001 foundation merged
    # in os#2; the mkConfigFlake port that replaces the placeholder host
    # roots with its disko/secure-boot/TPM stack is the follow-up).
    keystone-os = {
      url = "github:keystone-systems/os?dir=code";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Local development paths until the keystone-systems repos publish —
    # pure flake eval cannot resolve `path:../x` sibling inputs, so these
    # are absolute (same convention as the keystone-systems ks-config
    # template). Switch to github:keystone-systems/* once published.
    keystone-services = {
      url = "path:/home/ncrmro/repos/keystone-systems/services";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    keystone-terminal = {
      url = "path:/home/ncrmro/repos/keystone-systems/terminal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    keystone-desktop = {
      url = "path:/home/ncrmro/repos/keystone-systems/desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      keystone-os,
      keystone-services,
      keystone-terminal,
      keystone-desktop,
    }:
    let
      lib = nixpkgs.lib;

      # Load + validate keystone.json (generated from keystone.yaml).
      # Fails eval here — before any host is built — if an enabled service's
      # required secrets are missing from ./secrets.
      ksConfig = import ./lib/mkConfig.nix {
        configFile = ./keystone.json;
        secretsDir = ./secrets;
        catalog = keystone-services.lib.catalog;
      };

      svc = ksConfig.services;
      admin = ksConfig.admin.username;

      hasProfile = profile: host: builtins.elem profile (host.profiles or [ ]);

      # Bridge the loaded config into the services registry. Identical on
      # every host — that is what makes service declarations fleet-wide.
      fleetModule =
        { ... }:
        {
          keystone.services = {
            domain = svc.domain or null;
            frontdoor = svc.frontdoor or "nginx";
            tls = svc.tls or "none";
            forgejo.host = svc.forgejo.host or null;
            vaultwarden.host = svc.vaultwarden.host or null;
            immich.host = svc.immich.host or null;
            kubernetes = {
              host = svc.kubernetes.host or null;
              hostAddress = svc.kubernetes.hostAddress or null;
            };
          };
          keystone.secrets.root = ./secrets;

          time.timeZone = ksConfig.defaults.timeZone or null;

          users.users.${admin} = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = ksConfig.access.admin;
          };
          services.openssh.enable = true;
        };

      # Home Manager wiring per host: the terminal profile gives the admin
      # user the shared terminal environment (git identity from keystone.yaml);
      # the desktop profile layers the desktop environment on top.
      hmModuleFor = host: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${admin} = {
          imports =
            [ keystone-services.homeManagerModules.default ]
            ++ lib.optionals (hasProfile "terminal" host) [
              keystone-terminal.homeManagerModules.default
              {
                keystone.terminal = {
                  enable = true;
                  git = {
                    name = ksConfig.admin.fullName or null;
                    email = ksConfig.admin.email or null;
                  };
                };
              }
            ]
            ++ lib.optionals (hasProfile "desktop" host) [
              keystone-desktop.homeManagerModules.default
              {
                keystone.desktop = {
                  environment = host.desktop.environment or "hyprland";
                  # Editable dotfiles convention: clone this repo to
                  # ~/.config/keystone on the host; ./dotfiles is live-linked.
                  dotfiles.configRoot = "/home/${admin}/.config/keystone";
                };
              }
            ];
          keystone.services.client.email = ksConfig.admin.email;
          home.stateVersion = "25.05";
        };
      };

      linuxHosts = lib.filterAttrs (_: host: lib.hasSuffix "-linux" host.system) ksConfig.hosts;

      mkHost =
        name: host:
        nixpkgs.lib.nixosSystem {
          system = host.system;
          modules =
            [
              keystone-services.nixosModules.default
              home-manager.nixosModules.home-manager
              fleetModule
              (hmModuleFor host)
              ./hosts/${name}
              { networking.hostName = name; }
            ]
            ++ lib.optionals (hasProfile "terminal" host) [
              keystone-terminal.nixosModules.default
              { keystone.terminal.adminUsers = [ admin ]; }
            ]
            ++ lib.optionals (hasProfile "desktop" host) [
              keystone-desktop.nixosModules.default
              { keystone.desktop.linux.enable = true; }
            ];
        };
    in
    {
      # The validated, key-resolved fleet config — for tooling and for the
      # keystone os flake's mkConfigFlake once its port lands.
      keystoneConfig = ksConfig;

      nixosConfigurations = lib.mapAttrs mkHost linuxHosts;

      # `nix run .#vm-<host>` boots one host; `nix run .#fleet` boots them
      # all with SSH forwarded from localhost:2200 upward and graphical
      # consoles on QEMU VNC :0+ (both by sorted host name). See
      # docs/vm-fleet.md.
      apps.x86_64-linux = keystone-os.lib.mkFleetHarness {
        nixosConfigurations = self.nixosConfigurations;
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    };
}
