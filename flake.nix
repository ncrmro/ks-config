{
  description = "NCRMRO's NixOS config";

  inputs = {
    # Main package sources
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.follows = "keystone/home-manager";

    # Additional tools (follows keystone)
    nixos-hardware.follows = "keystone/nixos-hardware";

    # Private secrets repository (requires Tailscale connection to git.ncrmro.com)
    # This is a private repo - builds will fail without Tailscale access
    agenix-secrets = {
      url = "git+ssh://forgejo@git.ncrmro.com:2222/ncrmro/agenix-secrets.git";
      flake = false;
    };

    # AI coding agents — pin independently so llm-agents keeps its own nixpkgs
    # instead of being re-evaluated against this consumer's package set.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Active milestone-M10 dev: keystone is pinned to the local milestone
    # worktree because its option schema has not landed on keystone main yet.
    # App services such as Plouton are deployed from Forgejo OCI images through
    # keystone container workloads. Vega's central web/API also uses an OCI image,
    # but its native OS-agent bridge is packaged from this flake input so agent
    # services do not read source from the admin user's Vega checkout.
    vega = {
      url = "git+ssh://forgejo@git.ncrmro.com:2222/ncrmro/vega.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
    };

    # milestone/M10-V2-os-agents is the single canonical branch for Keystone
    # work right now. Keep this locked to GitHub so every host evaluates the
    # same committed Keystone revision; use bin/dev-keystone for local
    # path overrides while developing uncommitted Keystone changes.
    keystone = {
      url = "github:ncrmro/keystone/milestone/M10-V2-os-agents";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
    };

    # llama.cpp - latest for MXFP4 support (workstation-specific)
    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # New keystone-systems fleet harness (migration target for this repo).
    # Boots every host as a local QEMU VM so the fleet can be verified
    # before cutting over to the keystone-systems flakes. Pinned to the
    # feat/fleet-harness branch until keystone-systems/os#1 merges.
    keystone-os = {
      url = "github:keystone-systems/os/feat/fleet-harness?dir=code";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # New keystone-systems terminal and desktop fleet flakes, layered onto
    # the VM fleet (vmVariant only) so the VMs exercise the new stack.
    # Absolute path: URLs because pure flake eval cannot resolve `path:../x`
    # sibling inputs; switch to github:keystone-systems/* once those repos
    # publish (same convention as the keystone-systems ks-config template).
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
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    let
      # Import custom overlays
      overlays = import ./overlays { inherit inputs; };

      # Function to create system-specific packages with allowUnfree enabled
      pkgsForSystem =
        system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = overlays;
        };

      # Module args (`inputs`, `self`, `outputs`) are passed to every host
      # via mkSystemFlake's `shared.specialArgs`. They cannot be supplied via
      # `_module.args` because consumer modules (e.g.
      # modules/keystone/os.nix) reference `inputs.keystone.nixosModules.*`
      # inside their own `imports` list, and `_module.args` resolution
      # depends on `config`, which causes infinite recursion at import time.
      fleetSpecialArgs = {
        inherit inputs self;
        outputs = self;
      };

      # Fleet admin user. mkSystemFlake places this at
      # `keystone.os.users.<adminUsername>` with `admin = true`, so this is
      # the single source of truth for the ncrmro identity. The matching
      # block was removed from `modules/keystone/os.nix` during this migration.
      adminUser = {
        username = "ncrmro";
        fullName = "Nicholas Romero";
        terminal.enable = true;
        # Auto-load ncrmro's SSH key from agenix on every fleet host. Each host
        # must have ${hostname}-ncrmro-ssh-passphrase.age enrolled in
        # agenix-secrets; the assertion in keystone/modules/os/users.nix prints
        # the enrollment steps if missing.
        sshAutoLoad.enable = true;
        capabilities = [
          "ks"
          "engineer"
          "product"
          "project-manager"
        ];
      };

      # Storage devices are managed entirely by per-host disko configs in this
      # fleet (`keystone.os.storage.enable = false` in modules/keystone/os.nix).
      # mkLaptop/mkServer still require a storage.devices list for option-type
      # validation, so pass a placeholder. The keystone storage module is
      # gated on `storage.enable`, so these values are never read at runtime.
      placeholderDevices = [ "/dev/disk/by-id/placeholder-disko-managed" ];

      # All hosts that have ZFS backups declared need `storage.type = "zfs"`
      # to satisfy the keystone zfs-backup assertion, even when
      # `storage.enable = false` (this fleet handles ZFS via per-host disko
      # configs). mkLaptop's default of "ext4" trips the assertion on
      # ncrmro-laptop, so override here.
      zfsStorage = {
        type = "zfs";
        mode = "single";
        devices = placeholderDevices;
      };

      fleet = inputs.keystone.lib.mkSystemFlake {
        admin = adminUser;
        defaults = {
          timeZone = "America/Chicago";
          # Default the entire fleet to the unstable update channel.
          # Until ncrmro/keystone publishes a GitHub release, the stable
          # channel cannot resolve (404), so unstable is the only working
          # default. Per-host opt-back-in via `updateChannel = "stable"`.
          updateChannel = "unstable";
        };
        shared.specialArgs = fleetSpecialArgs;
        shared.systemModules = [
          # Experimental: zstd-compressed zram swap at 50% of RAM with
          # swappiness=150, so the kernel reaches for compressed swap
          # before evicting clean page-cache. See `keystone.os.zram.*`
          # in modules/os/zram.nix for tunables. Applies to every
          # mkSystemFlake-managed host (maia, ncrmro-laptop, mercury,
          # ocean, ncrmro-workstation); catalystPrimary is wired
          # manually below and unaffected.
          (
            { ... }:
            {
              keystone.os.zram.enable = true;
            }
          )
        ];
        hosts = {
          maia = {
            kind = "server";
            stateVersion = "25.11";
            # mkServer defaults to ZFS; placeholder devices are ignored
            # because keystone.os.storage.enable = false in this fleet.
            storage.devices = placeholderDevices;
            modules = [ ./hosts/maia ];
          };

          ncrmro-laptop = {
            kind = "laptop";
            stateVersion = "25.11";
            # Override mkLaptop's ext4 default — laptop runs ZFS via disko
            # and the keystone zfs-backup module asserts `storage.type ==
            # "zfs"` regardless of `storage.enable`.
            storage = zfsStorage;
            modules = [ ./hosts/ncrmro-laptop ];
          };

          mercury = {
            # server-vm: cloud/VPS kind. UEFI by default, no secureBoot/TPM,
            # ext4 storage — matches Vultr's qemu-guest image. Drops the
            # storage.devices placeholder, secureBoot/tpm off, and the
            # host-level bootloader workaround that the old `server` kind
            # required for mercury.
            kind = "server-vm";
            hostname = "mercury";
            stateVersion = "25.05";
            # Mercury reads ocean's generated DNS/ACL records as a specialArg.
            # The reference into `fleet.nixosConfigurations.ocean` is lazy:
            # ocean's config is only forced when mercury's modules actually
            # read `oceanConfig`, so there is no evaluation-time recursion.
            specialArgs = {
              oceanConfig = fleet.nixosConfigurations.ocean.config;
            };
            modules = [ ./hosts/mercury ];
          };

          # catalystPrimary is a non-keystone host (k3s VPS with hardcoded
          # SSH keys; see hosts/catalystPrimary/default.nix). It does NOT
          # import any keystone modules and does NOT want mkSystemFlake's
          # mkServer wrapper to force `keystone.os.enable = true` onto it.
          # This host is wired manually below the mkSystemFlake call as a
          # documented exception — see `nixosConfigurations.catalystPrimary`
          # at the end of the outputs block.

          ocean = {
            kind = "server";
            stateVersion = "25.11";
            storage.devices = placeholderDevices;
            modules = [ ./hosts/ocean ];
          };

          ncrmro-workstation = {
            # `workstation` is a distinct mkSystemFlake kind — it pre-pins a
            # ZFS-compatible kernel and enables the desktop archetype, which
            # is what this host wants.
            kind = "workstation";
            stateVersion = "25.11";
            storage.devices = placeholderDevices;
            modules = [ ./hosts/workstation ];
          };
        };
      };
      # VM-only hosts built purely from the new keystone-systems terminal and
      # desktop fleet flakes, booted by the fleet harness alongside the
      # legacy hosts. The legacy keystone modules declare the same
      # `keystone.terminal`/`keystone.desktop` option namespaces, so the new
      # stack cannot be layered onto the legacy hosts — it is verified side
      # by side instead, ahead of cutting this repo over.
      mkNewStackVmHost =
        { name, desktop }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            inputs.keystone-terminal.nixosModules.default
            {
              networking.hostName = name;
              keystone.terminal.adminUsers = [ adminUser.username ];
              users.users.${adminUser.username} = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
              };
              services.openssh.enable = true;
              # Placeholder rootfs/bootloader: only the vmVariant is ever
              # built for these hosts and it overrides both.
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
              };
              boot.loader.systemd-boot.enable = true;
              system.stateVersion = "25.11";
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${adminUser.username} = {
                imports = [
                  inputs.keystone-terminal.homeManagerModules.default
                ]
                ++ nixpkgs.lib.optional desktop inputs.keystone-desktop.homeManagerModules.default;
                keystone.terminal = {
                  enable = true;
                  git.name = adminUser.fullName;
                  git.email = "${adminUser.username}@ncrmro.com";
                };
                home.stateVersion = "25.11";
              };
            }
          ]
          ++ nixpkgs.lib.optionals desktop [
            inputs.keystone-desktop.nixosModules.default
            {
              keystone.desktop.linux.enable = true;
              home-manager.users.${adminUser.username}.keystone.desktop = {
                environment = "hyprland";
                dotfiles.configRoot = "/home/${adminUser.username}/.config/keystone";
              };
            }
          ];
        };

      newStackVmHosts = {
        ks-terminal = mkNewStackVmHost {
          name = "ks-terminal";
          desktop = false;
        };
        ks-desktop = mkNewStackVmHost {
          name = "ks-desktop";
          desktop = true;
        };
      };
    in
    fleet
    // {
      # `catalystPrimary` is wired manually as an exception: it does not use
      # the keystone OS module (k3s VPS, hardcoded SSH keys), so wrapping it
      # via mkSystemFlake would force `keystone.os.enable = true` and trip
      # the storage / fileSystems assertions. Merging into nixosConfigurations
      # via attribute-set extension keeps it discoverable alongside the rest.
      nixosConfigurations =
        fleet.nixosConfigurations
        # ks-terminal/ks-desktop: VM-only new-stack test hosts (see
        # mkNewStackVmHost above); exposed here so they are discoverable and
        # `nix build .#nixosConfigurations.ks-*...` works — never deployed.
        // newStackVmHosts
        // {
          catalystPrimary = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./hosts/catalystPrimary ];
            specialArgs = {
              inherit inputs self;
              outputs = self;
            };
          };
        };

      # VM fleet test harness from keystone-systems: `nix run .#vm-<host>`
      # boots one host's vmVariant; `nix run .#fleet` boots the whole fleet
      # headless with SSH forwarded from localhost:2200 upward (sorted by
      # host name) and consoles on VNC :0+. This is the pre-cutover
      # verification path — the same harness the keystone-systems ks-config
      # template uses, run against this repo's real hosts.
      #
      # Alongside the legacy hosts, `ks-terminal` and `ks-desktop` are
      # VM-only hosts built purely from the new keystone-systems terminal and
      # desktop fleet flakes (the legacy keystone modules declare the same
      # `keystone.terminal`/`keystone.desktop` option namespaces, so the new
      # stack cannot be layered onto the legacy hosts — it boots side by side
      # instead). catalystPrimary is excluded: it is the documented
      # non-keystone exception above and is not part of the migration.
      apps.x86_64-linux =
        (fleet.apps.x86_64-linux or { })
        // inputs.keystone-os.lib.mkFleetHarness {
          nixosConfigurations = fleet.nixosConfigurations // newStackVmHosts;
        };

      # Code formatter (official NixOS formatter)
      formatter.x86_64-linux = (pkgsForSystem "x86_64-linux").nixfmt;
      formatter.aarch64-darwin = (pkgsForSystem "aarch64-darwin").nixfmt;

      # Custom packages — extend whatever mkSystemFlake exposes (e.g.
      # installerTargetsJson, vm-image-*, iso) with our own.
      packages.x86_64-linux =
        let
          pkgs = pkgsForSystem "x86_64-linux";
          # Portable devbox image — built from a standalone home-manager
          # profile via the spike helper at modules/keystone-spike/. This
          # whole block moves out of this repo once the staging contents
          # graduate to ncrmro/keystone (see modules/keystone-spike/README.md).
          devboxNcrmroHome = import ./modules/keystone-spike/lib/portable-terminal.nix {
            inherit inputs;
            system = "x86_64-linux";
            fullName = adminUser.fullName;
            email = "${adminUser.username}@ncrmro.com";
          };
          devboxNcrmroImage = pkgs.callPackage ./modules/keystone-spike/packages/devbox-image {
            homeActivationPackage = devboxNcrmroHome.activationPackage;
            ks = pkgs.keystone.ks or null;
            imageName = "devbox-${adminUser.username}";
            extraContents = [
              inputs.llm-agents.packages.x86_64-linux.pi
            ];
          };
        in
        (fleet.packages.x86_64-linux or { })
        // {
          inherit (pkgs.keystone)
            claude-code
            codex
            gemini-cli
            zesh
            ;
          pi = inputs.llm-agents.packages.x86_64-linux.pi;
          inherit (pkgs) mcp-language-server devbox;

          # Portable per-user devbox container image (spike).
          "devbox-image-${adminUser.username}" = devboxNcrmroImage;

          # Installer ISO — keys auto-collected from keystone.os.users (wheel) + hardware root keys
          iso = fleet.nixosConfigurations.ncrmro-workstation.config.keystone.os.installer.isoImage;
        };

      # Import NixOS and Home Manager modules
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # macOS Home Manager configurations — mkSystemFlake doesn't manage these
      # because macOS hosts here are user-only, not full system flakes.
      homeConfigurations = {
        "nicholas@unsup-macbook" = home-manager.lib.homeManagerConfiguration {
          modules = [ ./home-manager/ncrmro/unsup-macbook.nix ];
          pkgs = pkgsForSystem "aarch64-darwin";
          extraSpecialArgs = { inherit inputs self; };
        };
        "ncrmro@ncrmro-macbook" = home-manager.lib.homeManagerConfiguration {
          modules = [ ./home-manager/ncrmro/ncrmro-macbook.nix ];
          pkgs = pkgsForSystem "aarch64-darwin";
          extraSpecialArgs = { inherit inputs self; };
        };
      };

      # Development shells
      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = [ nixpkgs.legacyPackages.x86_64-linux.nixfmt ];
        shellHook = ''
          build() {
            local hosts=(maia ncrmro-laptop mercury catalystPrimary ocean ncrmro-workstation)
            local failed=()
            for host in "''${hosts[@]}"; do
              echo "Building $host..."
              if ! nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --no-link 2>&1; then
                failed+=("$host")
              fi
            done
            if [ ''${#failed[@]} -eq 0 ]; then
              echo "All hosts built successfully."
            else
              echo "Failed: ''${failed[*]}"
              return 1
            fi
          }

        '';
      };

      devShells.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
        packages = [ nixpkgs.legacyPackages.aarch64-darwin.nixfmt ];
      };
    };
}
