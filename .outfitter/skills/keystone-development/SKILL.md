---
name: keystone-development
description: Develop keystone-systems and the user's ks-config — flake wiring, the stow dotfiles convention, and the VM fleet for verification. Use for any keystone-systems or ks-config work.
---

# Keystone development

## Repos and wiring

- **ks-config** (this repo) — the user's fleet config: keystone.yaml →
  `scripts/generate-config.sh` → committed keystone.json → `lib/mkConfig.nix`
  validates at eval. Edit the YAML, regenerate, commit both. Work happens
  on the refactor worktree: `~/repos/ncrmro/worktrees/ks-config/feat/keystone-systems-fleet-harness`
  (`$KS` below); never edit the main checkout directly.
- **Component flakes** — `~/repos/keystone-systems/{os,desktop,terminal,services}`.
  ks-config consumes them as absolute `path:` inputs (pure eval cannot
  resolve `path:../x`); after editing one, run `nix flake update <input>`
  in `$KS` or the change is invisible.
- **Dotfiles** — `$KS/dotfiles/<app>` is a stow tree, whole-dir symlinked
  onto `~/.config/<app>` by the desktop flake. Dotfile edits are live (no
  rebuild); nix-level edits need rebuild + VM cycle.
  references/development.dotfiles.md has the live-vs-rebuild split.
- **Legacy reference** — `~/repos/ncrmro/keystone` (read-only migration
  source; theming notes in `keystone-systems/desktop/docs/theming.md`).

## Verifying with the VM fleet

Changes are verified by booting the fleet as local QEMU VMs. For anything
VM-fleet related — booting, cycling, ports, screenshots, ssh — read
`references/vm-fleet-harness.md` first and use its commands verbatim.

## References

- `references/vm-fleet-harness.md` — boot/cycle the fleet, port map,
  VNC screenshots, ssh access. **Start here for any VM work.**
- `references/development.dotfiles.md` — stow convention, 9p live mount,
  live vs rebuild, per-app reload commands.
- `references/development.desktop.md` — screenshots, input, hyprctl/waybar
  reload signals, unlocking hyprlock, diagnosing a broken session.
- `references/development.headless.md` — harness internals, serial logs,
  ssh, journal access, rebuild/cycle mechanics, common failure modes.
