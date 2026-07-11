# Dotfiles iteration (stow tree, 9p live mount, reload loops)

## The convention

`$KS/dotfiles/<app>` is a stow tree. The desktop flake
(`desktop/modules/dotfiles/home-manager-links.nix`) whole-dir symlinks it
onto the paths apps read — links only, never copies:

```
~/.config/hypr    → ~/.config/keystone/dotfiles/hyprland
~/.config/zellij  → ~/.config/keystone/dotfiles/zellij
~/.config/yazi    → ~/.config/keystone/dotfiles/yazi
(+ waybar, niri config.kdl, aerospace toml, gnome dconf dump, zsh session)
```

`~/.config/keystone` is the ks-config checkout: cloned on real hosts,
**9p-mounted from the host's worktree in VMs** (vmVariant
`sharedDirectories`) — an edit on the host is in the VM instantly.

## What's live vs what needs a rebuild + VM cycle

LIVE (edit in `$KS/dotfiles/`, then send the app its reload signal):
- any file inside an already-linked app dir, including NEW files
  (whole-dir links) — hyprland fragments, waybar config/style, zellij
  layouts, yazi plugins, hyprlock.conf.

REBUILD (nix change → `nix flake update <input>` in `$KS` → rebuild →
cycle VM with fresh qcow2):
- linking a NEW app dir (edit home-manager-links.nix in the desktop flake)
- packages, fonts, session/autologin, NixOS options, HM options.

## Reload signals per app

```bash
hyprctl reload                       # hyprland fragments
pkill -SIGUSR2 waybar                # waybar style.css only
pkill waybar && hyprctl dispatch exec waybar   # waybar config changes
pkill -USR2 hyprlock                 # re-render lock screen; -USR1 unlocks
makoctl reload                       # mako
# zellij/yazi: restart the program (configs read at start)
```

(hyprctl over ssh needs `XDG_RUNTIME_DIR=/run/user/1000` and
`HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr | head -1)`.)

## Theming (recorded, not yet implemented)

Legacy keystone routes every app through one mutable symlink
(`~/.config/keystone/current/theme → themes/<name>`); switching is
`ln -sfn` + reload signals — atomic, no rebuild. Adaptation plan: a
git-tracked `dotfiles/current-theme` symlink inside the stow tree, so a
switch is both live and a visible repo change. Full write-up:
`~/repos/keystone-systems/desktop/docs/theming.md`.

## Gotchas

- `readlink ~/.config/hypr` shows the intermediate store hop; use
  `readlink -f` to see the final stow-tree target.
- A dir that exists in the stow tree but is NOT in
  home-manager-links.nix silently does nothing — the app falls back to
  defaults (how the unstyled-waybar breakage happened).
- programs.<app> HM modules that generate config files collide with the
  dir links — install such apps as plain `home.packages` instead
  (yazi/zellij are already handled this way).
