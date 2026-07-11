# Headless VM debugging (ssh, serial, harness internals)

## Harness

`keystone-os.lib.mkFleetHarness` (github:keystone-systems/os?dir=code)
wraps each host's `system.build.vm` with a vmVariant: 4G/2 cores,
SSH forwarded from 2200 + index, QEMU VNC `:index` (5900 + index), by
**sorted host name**. Apps: `nix run $KS#vm-<host>`, `nix run $KS#fleet`
(disks/logs in `$KEYSTONE_FLEET_DIR`, default `./.fleet` — this project
uses `/tmp/ncrmro-fleet`).

## SSH

Two auth paths into VMs:

- Password `keystone` (vmVariant-only initialPassword) — the automation
  path; wrap with sshpass and force password auth (see SKILL.md).
  Locale/known-hosts flags matter: always `-o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null` since host keys regenerate per disk.
- keystone.yaml keys — works, but FIDO2 keys need an interactive touch;
  BatchMode fails at "agent refused operation" (that error actually
  *proves* the authorized_keys wiring: sshd accepted the pubkey and asked
  for a signature).

Root: none (no root password/keys in VMs; use `wheel` + sudo — the admin
user is in wheel, sudo asks the `keystone` password inside VMs).

## Serial console / boot logs

With the default harness (`graphics = true` + VNC) the kernel console goes
to the virtual terminal, NOT stdout — the per-VM `.log` files only show
disk-image creation. To capture a serial boot log, run the VM with
`-display none -serial stdio` extra args, or read the journal over ssh:

```bash
journalctl -b --no-pager | tail -50        # whole boot
journalctl -u greetd -u home-manager-ncrmro.service --no-pager
systemctl --failed
```

## Rebuild / cycle mechanics

- Component-flake change (desktop/terminal/services/os): commit not
  required, but `$KS` locks the path inputs by narHash — run
  `nix flake update <input>` in `$KS` after any edit.
- `nix build $KS#nixosConfigurations.<host>.config.system.build.vm` to
  prebuild; `nix run` builds the port-forwarded variant on demand (cheap).
- Cycle = pkill the VM (bracket-trick the pattern so pkill doesn't match
  your own command line: `pkill -f "qemu.*ncrmro-lapto[p]"`), delete its
  qcow2 for a fresh first boot (HM activation, tmpfiles, initialPassword
  only apply cleanly on fresh state), rerun.
- `pkill` returning exit 144 after killing its own shell = the pattern
  matched your invoking command; nothing after the pkill in that command
  ran — re-issue the rest.

## Known failure modes

- `nix flake show` error "access to absolute path '/nix/store/...' is
  forbidden": a `path:../x` sibling input — must be absolute `path:/...`
  (pure eval copies flakes to the store; siblings never resolve).
- Missing file in eval on a git-repo flake: the file isn't `git add`ed.
- agenix secrets do not decrypt in VMs (no enrolled host key) — any
  secret-backed unit fails there by design; none enabled yet.
- Port already bound: a previous VM instance is still alive — check
  `ss -tln | grep -E ':(220|590)'` and pkill it.
