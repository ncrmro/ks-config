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
    # Vega itself is deployed from the Forgejo OCI image, not as a ks-config
    # flake input/package.

    # NEVER CHANGE THIS URL. EVER. milestone/M10-V2-os-agents is the
    # single canonical branch for keystone work right now — squash /
    # cherry-pick new commits onto it instead of repointing the flake
    # at a different branch. If a change is needed here, ask first.
    keystone = {
      url = "path:/home/ncrmro/repos/ncrmro/worktrees/keystone/milestone/M10-V2-os-agents";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
    };

    # llama.cpp - latest for MXFP4 support (workstation-specific)
    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plouton — FastAPI + Astro SPA, hosted on ocean. Use the canonical
    # Forgejo main branch so every host can evaluate the same lock without
    # requiring an identical local checkout at ~/repos/ncrmro/plouton.
    plouton = {
      url = "git+ssh://forgejo@git.ncrmro.com:2222/ncrmro/plouton.git?lfs=1";
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
    in
    fleet
    // {
      # `catalystPrimary` is wired manually as an exception: it does not use
      # the keystone OS module (k3s VPS, hardcoded SSH keys), so wrapping it
      # via mkSystemFlake would force `keystone.os.enable = true` and trip
      # the storage / fileSystems assertions. Merging into nixosConfigurations
      # via attribute-set extension keeps it discoverable alongside the rest.
      nixosConfigurations = fleet.nixosConfigurations // {
        catalystPrimary = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/catalystPrimary ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
          };
        };
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
