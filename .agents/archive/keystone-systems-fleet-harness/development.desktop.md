# Desktop VM iteration (screenshots, input, session debugging)

Desktop hosts (ncrmro-laptop, ncrmro-workstation) boot greetd → auto-login
→ Hyprland (vmVariant only). The QEMU VNC server is always on, so Claude
can see and drive the session without touching the user's display.

## Screenshots

```bash
mkdir -p /tmp/ks-shots
nix shell nixpkgs#gtk-vnc -c gvnccapture 127.0.0.1:0 /tmp/ks-shots/laptop.png       # display :0 = port 5900
nix shell nixpkgs#gtk-vnc -c gvnccapture 127.0.0.1:1 /tmp/ks-shots/workstation.png
```

Read the png afterwards. Verified working 2026-07-11. If gvnccapture hangs,
the VM is mid-boot — check `ss -tln | grep 590`.

## Driving the session (input)

Prefer hyprctl over ssh — deterministic and scriptable:

```bash
# inside the VM via ssh (see SKILL.md for the sshpass invocation):
export XDG_RUNTIME_DIR=/run/user/1000
export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1)
hyprctl dispatch exec 'ghostty'        # launch something
hyprctl dispatch workspace 2
hyprctl reload                          # re-read dotfiles
hyprctl clients / monitors / layers -j  # inspect state as JSON
```

Raw keystrokes/mouse when hyprctl can't reach it (e.g. the lock screen):
launch the VM with a QMP socket and use `sendkey`/`input-send-event`:

```bash
nix run $KS#vm-ncrmro-laptop -- -display gtk -qmp unix:/tmp/qmp-laptop.sock,server,nowait
# then: printf '{"execute":"qmp_capabilities"}\n{"execute":"human-monitor-command","arguments":{"command-line":"sendkey k"}}\n' \
#   | nix shell nixpkgs#socat -c socat - UNIX-CONNECT:/tmp/qmp-laptop.sock
```

## hyprlock

- VMs: the account password is `keystone` (vmVariant initialPassword) —
  type it in the headed window, or bypass for iteration:
  `pkill -USR1 hyprlock` (instant unlock) / `pkill -USR2 hyprlock`
  (re-render) over ssh.
- hyprlock.conf lives in the stow tree (`dotfiles/hyprland/hyprlock.conf`,
  read as `~/.config/hypr/hyprlock.conf`) — edits are live, re-run hyprlock
  to see them.

## Diagnosing a broken-looking session

Checklist that found real issues (2026-07-11 — unstyled rainbow waybar,
missing glyphs, no lock screen):

1. Screenshot first; don't guess from logs.
2. `pgrep -af` the expected autostart set: waybar, mako, hyprpaper,
   hypridle, hyprpolkitagent (from `dotfiles/hyprland/autostart.conf`).
3. Unstyled waybar (default blue/yellow/green modules) = waybar found no
   `~/.config/waybar/` — the app's dir must exist in the stow tree AND be
   linked by `desktop/modules/dotfiles/home-manager-links.nix`.
4. Tofu boxes (▯▯) = icon fonts missing from the NixOS closure
   (`fonts.packages` in the desktop linux platform module).
5. Session logs: `journalctl -u greetd`, crash reports in
   `~/.cache/hyprland/hyprlandCrashReport*`, waybar/mako stderr in
   `journalctl --user -t` or run them by hand in the session env.
6. `hyprctl layers -j` shows what actually rendered (waybar/hyprlock are
   layer-shell surfaces).
