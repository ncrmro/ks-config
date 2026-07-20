## Repository Overview

This is a NixOS configuration repository using flakes for managing system configurations across multiple hosts. The repository manages both NixOS system configurations and Home Manager user configurations, with a focus on infrastructure-as-code patterns.

## Architecture

### Core Components

- **Flake-based Configuration**: All system configurations are managed through `flake.nix` which defines multiple NixOS systems and Home Manager configurations
- **Host-specific Configurations**: Each host (maia, ocean, mercury, etc.) has its own configuration in `/hosts/<hostname>/`
- **Modular Structure**: Common configurations are shared via `/hosts/common/` with optional features that can be imported per-host
- **Kubernetes Integration**: Several hosts run K3s with NixOS-managed Kubernetes resources
- **ZFS Storage**: Many systems use ZFS with LUKS encryption and remote replication
- **Secret Management**: Uses agenix for encrypted secrets management

### Directory Structure

- `/hosts/` - Host-specific configurations
  - `/common/global/` - Global settings applied to all hosts
  - `/common/optional/` - Optional modules (tailscale, docker, k3s, etc.)
  - `/common/kubernetes/` - Kubernetes module definitions
- `/home-manager/` - User-specific Home Manager configurations
- `/modules/` - Custom NixOS and user modules (keystone wrappers, local NixOS modules, user definitions)
- `../keystone/` - Sibling checkout of [ncrmro/keystone](https://github.com/ncrmro/keystone)
- `/bin/` - Helper scripts for deployment and management
- `/docs/` - Documentation for various setup procedures
- `/kubernetes/` - Raw Kubernetes manifests (legacy)
- `/agenix-secrets/` - Local clone of private agenix secrets repo (gitignored)

### Local Repo Clones

Keystone development happens in the sibling checkout at `../keystone`. The authoritative version pin used by ks-config lives in `flake.lock`.

**Setup after fresh clone:**
```bash
git clone ssh://forgejo@git.ncrmro.com:2222/ncrmro/agenix-secrets.git agenix-secrets
```

**Agenix secrets contents:**
- `secrets.nix` - Defines which SSH keys can decrypt which secrets
- `secrets/` - Directory containing all `.age` encrypted secret files

## Common Commands

### Building and Deploying

Host connection details are defined in `hosts.nix` (single source of truth) and
consumed by both the `keystone.hosts` NixOS module and the `ks` CLI.

```bash
# Check flake configuration
nix flake check

# Build a host config (no deploy, no sudo)
ks build [<HOSTS>]                 # defaults to current hostname; --lock builds full NixOS system
ks build ocean                     # build ocean config
ks build ocean,maia                # build multiple configs

# Build/deploy with local input overrides (keystone, agenix-secrets) — the
# `ks` CLI no longer has a --dev flag; use bin/ks-dev instead
./bin/ks-dev --build [HOST]        # build only, no activation, no sudo
./bin/ks-dev [HOST]                # build and switch (default)
./bin/ks-dev --boot [HOST]         # build and set as boot generation

# Deploy to a host with locked inputs (switch or boot)
ks update [--boot] [<HOSTS>]         # defaults to current hostname, locks by default
ks update ocean                      # deploy to ocean (Tailscale, LAN fallback)
ks update mercury,ocean              # deploy multiple (builds all first, then sequential)
ks update --boot                     # nixos-rebuild boot (reboot required)
```

`ks` is installed globally via `keystone.terminal`. It discovers the repo via
`$NIXOS_CONFIG_DIR`, the git root of the current directory, `/run/current-system/keystone-system-flake`, or `~/repos/<user>/ks-config`.
The `bin/build` and `bin/update` shims delegate to `ks` for backwards compatibility.

### Committing and Pushing Keystone / Agenix Changes

When changes span keystone or agenix-secrets:

1. Commit and push from the source repo (`cd ../keystone && git push` or `cd agenix-secrets && git push`)
2. Update the flake lock for the changed inputs: `nix flake update keystone` (or `agenix-secrets`, or both)
3. Commit `flake.lock` in ks-config
4. Push ks-config

Before pushing, always build the workstation host to verify:
`./bin/ks-dev --build` (local overrides) or `nixos-rebuild build --flake .#ncrmro-workstation` (locked inputs)

### Development Workflow

```bash
# Check and format code before committing
./bin/check

# Setup pre-commit hooks
./bin/setup-precommit

# Test configuration in VM
nix build .#nixosConfigurations.test-vm.config.system.build.vm
./result/bin/run-test-vm-vm
```

### Home Manager

Home Manager is integrated into NixOS and activated automatically during `nixos-rebuild switch`. **Never run `home-manager switch` directly** - it will cause conflicts with the NixOS-managed home-manager service.

```bash
# CORRECT: Home Manager is applied as part of NixOS rebuild
sudo nixos-rebuild switch --flake .#<hostname>

# WRONG: Do not use home-manager directly
# home-manager switch --flake .#ncrmro@<hostname>  # Don't do this!
```

## Configuration Patterns

### Adding a New Host

1. Create directory `/hosts/<hostname>/`
2. Add `default.nix` with host configuration
3. Add `hardware-configuration.nix` (generate with `nixos-generate-config`)
4. Optional: Add `disk-config.nix` for disko-managed disk layout
5. Register in `flake.nix` under `nixosConfigurations`

### Enabling Optional Features

Import from `/hosts/common/optional/` in your host's `default.nix`:

```nix
imports = [
  ../common/global
  ../common/optional/tailscale.nix
  ../common/optional/docker-rootless.nix
];
```

### Kubernetes Resources

For hosts running K3s, Kubernetes resources can be managed through NixOS modules in `/hosts/common/kubernetes/`. These modules use the `services.k3s.autoDeployCharts` for Helm chart deployments and raw manifest application.

#### Important: Helm Chart Hash Values

When using `services.k3s.autoDeployCharts`, the initial `hash` value should always be an empty string `""`, not `"sha256-PLACEHOLDER"` or similar placeholders. This allows Nix to fetch the chart and emit the proper hash on first deployment.

```nix
services.k3s.autoDeployCharts = {
  example-chart = {
    name = "example";
    repo = "https://charts.example.com";
    version = "1.0.0";
    hash = ""; # Use empty string for initial deployment
    targetNamespace = "default";
    values = { /* chart values */ };
  };
};
```

After the first deployment attempt, Nix will provide the correct hash which should then be updated in the configuration.

## Key Technologies

- **NixOS unstable**: nixpkgs follows keystone's nixpkgs (nixos-unstable)
- **Disko**: Declarative disk partitioning
- **Lanzaboote**: Secure Boot support
- **K3s**: Lightweight Kubernetes
- **ZFS**: Advanced filesystem with snapshots and replication
- **Tailscale/Headscale**: Mesh VPN networking
- **Agenix**: Secret management

## Important Notes

- Use `nix flake check` to validate configuration before deployment
- Host-specific secrets are in `/agenix-secrets/secrets/` and require appropriate age keys
- ZFS systems require `networking.hostId` to be set uniquely per host
- Secure Boot systems use TPM for automatic disk unlock
