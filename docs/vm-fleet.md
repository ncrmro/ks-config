# VM fleet harness

The keystone-systems os harness boots every Linux host in keystone.yaml as
a local QEMU VM — the verification path while the fleet is VM-only (see
docs/migration-to-keystone-systems.md).

```bash
nix run .#fleet             # boot all hosts; disks/logs in ./.fleet
nix run .#vm-ocean          # boot one host
nix run .#vm-ncrmro-laptop
```

Ports are stable, assigned by sorted host name:

| Host | SSH | VNC display | VNC port |
| --- | --- | --- | --- |
| ncrmro-laptop | `ssh -p 2200 localhost` | `:0` | 5900 |
| ncrmro-workstation | `ssh -p 2201 localhost` | `:1` | 5901 |
| ocean | `ssh -p 2202 localhost` | `:2` | 5902 |

Each VM's graphical console is on QEMU's built-in VNC server, bound on all
interfaces so another machine can attach (e.g. from the laptop:
`vncviewer ncrmro-workstation:5900`). VNC is unauthenticated — tailnet or
SSH tunnel only.

Two tiers per desktop host:

- **Primary** (`vm-<host>`, `fleet`): fresh-install semantics. The VM is
  self-contained — greetd shows the real agreety login (user `ncrmro`,
  password `keystone` in VMs), and `~/.config/keystone` is a copy of the
  **committed** flake tree, simulating the user's clone. A dotfile that
  works here works on a real install; uncommitted files are excluded, so
  "forgot to commit it" fails here just like it would in production.
- **Dev** (`vm-dev-<host>`): fast iteration. Auto-login straight into the
  session, and this repo's live checkout 9p-mounted over
  `~/.config/keystone` — edit a dotfile on the host, `hyprctl reload` in
  the VM, done. Shares the primary's port slot: run one or the other.

The stow-style symlinks (`~/.config/hypr → ~/.config/keystone/dotfiles/hyprland`,
same for `waybar`, `zellij`, `yazi`) are identical in both tiers; only
what sits at `~/.config/keystone` differs. VM-only conveniences never
reach real host builds.

Notes:

- SSH auth uses the keys declared in keystone.yaml (`access.admin`).
- agenix secrets do not decrypt inside VMs (no enrolled host key), so any
  secret-backed unit would fail; none are enabled yet.
- Desktop hosts show the virtual console — no display manager/compositor
  autostart in the desktop flake yet.
- `KEYSTONE_FLEET_DIR` overrides where disks and logs are written.
