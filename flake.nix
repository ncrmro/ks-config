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

    # llm-agents — follows keystone's pin (updated when keystone is relocked)
    llm-agents.follows = "keystone/llm-agents";

    # Keystone - self-sovereign infrastructure platform
    # NEVER CHANGE THIS URL TO A LOCAL PATH. EVER. USE THE GITHUB REPO.
    # For local dev without commits, use: ./bin/dev-keystone <hostname>
    keystone = {
      url = "github:ncrmro/keystone";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # llama.cpp - latest for MXFP4 support (workstation-specific)
    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
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
    in
    {
      # Code formatter (official NixOS formatter)
      formatter.x86_64-linux = (pkgsForSystem "x86_64-linux").nixfmt;
      formatter.aarch64-darwin = (pkgsForSystem "aarch64-darwin").nixfmt;

      # Custom packages
      packages.x86_64-linux =
        let
          pkgs = pkgsForSystem "x86_64-linux";
        in
        {
          inherit (pkgs.keystone)
            claude-code
            codex
            gemini-cli
            zesh
            ;
          inherit (pkgs) mcp-language-server;

          # Installer ISO — keys auto-collected from keystone.os.users (wheel) + hardware root keys
          iso = self.nixosConfigurations.ncrmro-workstation.config.keystone.os.installer.isoImage;
        };

      # Import NixOS and Home Manager modules
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      # NixOS system configurations
      nixosConfigurations = {
        # Home server configuration
        maia = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/maia ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
          };
        };

        ncrmro-laptop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/ncrmro-laptop ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
          };
        };
        mercury = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/mercury ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
            oceanConfig = self.nixosConfigurations.ocean.config;
          };
        };
        catalystPrimary = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/catalystPrimary ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
          };
        };
        ocean = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/ocean ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
          };
        };
        ncrmro-workstation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./hosts/workstation ];
          specialArgs = {
            inherit inputs self;
            outputs = self;
          };
        };
      };

      # Home Manager configurations
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
