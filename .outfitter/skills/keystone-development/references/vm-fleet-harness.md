# VM fleet harness

Boot, cycle, observe, and log into the QEMU dev fleet defined by
ks-config (`$KS` = the refactor worktree).

## Two tiers — pick deliberately

- `vm-<host>` / `fleet` — **primary, fresh-install semantics**: greetd
  login screen, `~/.config/keystone` is a copy of the committed tree
  (uncommitted files absent, like a real clone). Use to verify.
- `vm-dev-<host>` — **iteration**: auto-login into the session, live
  checkout 9p-mounted over the configRoot (host edits appear instantly).
  Use to develop. Same port slot as the primary — run one or the other.

## Boot

```bash
cd /tmp/ncrmro-fleet                           # disks + logs by convention
nix run $KS#vm-ncrmro-laptop -- -display gtk   # primary, headed window
nix run $KS#vm-dev-ncrmro-laptop -- -display gtk   # dev variant
nix run $KS#fleet                              # all primaries, VNC-only
```

Ports by sorted host name: ssh 2200+i, VNC 5900+i (ncrmro-laptop →
2200/:0, ncrmro-workstation → 2201/:1, ocean → 2202/:2).

## Cycle after a nix-level change

Dotfile-only edits need no cycle (see development.dotfiles.md).

```bash
pkill -f "qemu.*ncrmro-lapto[p]"   # bracket trick: don't match your own cmdline
rm -f /tmp/ncrmro-fleet/ncrmro-laptop.qcow2   # fresh state
```

## Screenshot (how Claude sees the desktop)

```bash
nix shell nixpkgs#gtk-vnc -c gvnccapture 127.0.0.1:0 /tmp/ks-shots/laptop.png
```

Then Read the png. Works against the harness's always-on VNC — no VM
flags needed.

## SSH

```bash
nix shell nixpkgs#sshpass -c sshpass -p keystone \
  ssh -p 2200 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      ncrmro@127.0.0.1 'hostname'
```

Password `keystone` is a vmVariant-only convenience on desktop hosts (it
also unlocks hyprlock); ocean is key-only. Real keystone.yaml keys work
with an interactive YubiKey touch.
