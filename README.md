# ncrmro fleet config (keystone-systems)

User-owned shared config for the ncrmro fleet, built on the
[keystone-systems](https://github.com/keystone-systems) flakes.
`keystone.yaml` is the single source of truth — hosts, keys, access,
services, clusters. Edit it, run `scripts/generate-config.sh`, commit both
files.

> **Migration in progress.** This branch replaced the legacy
> ncrmro/keystone mkSystemFlake fleet wholesale; it is VM-harness-only
> until the keystone-systems os flake's storage/secure-boot port lands.
> `main` remains the deployable flake. What was dropped and the parity
> checklist: [docs/migration-to-keystone-systems.md](docs/migration-to-keystone-systems.md).

## Layout

- `keystone.yaml` → `keystone.json` (generated) → `lib/mkConfig.nix`
  validates and resolves the fleet config at eval time.
- `hosts/<name>/` — per-host overrides (placeholders until the os port).
- `secrets/` — agenix secrets, recipients derived from keystone.yaml keys.
- `dotfiles/` — editable desktop/terminal dotfiles, live-linked from
  `~/.config/keystone` on desktop hosts.

## Usage

```bash
nix flake show              # nixosConfigurations + harness apps
nix run .#fleet             # boot every host as a QEMU VM
nix run .#vm-<host>         # boot one host
```

SSH and VNC ports per host: [docs/vm-fleet.md](docs/vm-fleet.md).

## Operational documentation

Legacy-era guides in `docs/` (install, headscale/tailscale, kubernetes,
ZFS, keybindings, …) describe the deployed fleet on `main`; they migrate
into the keystone-systems docs as parity items land.
