# VM fleet

## Whole-fleet VMs via the keystone-systems harness

The new keystone-systems migration target ships a fleet harness
(`github:keystone-systems/os?dir=code`) that this flake now consumes: it
wraps every mkSystemFlake host's `vmVariant` as a runnable app, so the real
fleet can be booted and verified locally before cutting this repo over to
the keystone-systems flakes.

The fleet also includes two VM-only hosts built purely from the new
keystone-systems **terminal** and **desktop** fleet flakes: `ks-terminal`
(new terminal stack) and `ks-desktop` (terminal + Hyprland desktop). The
legacy keystone modules declare the same
`keystone.terminal`/`keystone.desktop` option namespaces, so the new stack
cannot be layered onto the legacy hosts — these boot side by side instead.

```bash
nix run .#fleet                  # boot all hosts headless; disks/logs in ./.fleet
nix run .#vm-ks-terminal         # or boot one host
nix flake show                   # lists vm-<host> apps

# SSH ports are 2200 + index by sorted host name:
#   ks-desktop 2200, ks-terminal 2201, maia 2202, mercury 2203,
#   ncrmro-laptop 2204, ncrmro-workstation 2205, ocean 2206
ssh -p 2201 localhost

# Each console is on QEMU's built-in VNC server at display :index
# (port 5900+index), unauthenticated — reach it over the tailnet or an
# SSH tunnel only.
vncviewer localhost:5900
```

VMs get 4G RAM / 2 cores each; the full seven-host fleet needs ~28G free.
`catalystPrimary` is excluded (non-keystone exception, not migrating).
agenix secrets do not decrypt inside the VMs (the VM has no enrolled host
key), so secret-backed services will fail their units — expected; the
harness verifies boot, activation, and module wiring, not secrets.

The keystone-systems terminal and desktop flakes are consumed as absolute
`path:` inputs (pure flake eval cannot resolve `path:../x` siblings);
switch them to `github:keystone-systems/*` once those repos publish — the
same convention and caveat as the keystone-systems ks-config template.

## devenv/process-compose pilot (vm-tpm-microvm)

The VM fleet is the single entry point for running keystone test VMs locally.
Each VM is a `process` declared in `devenv.nix` and managed by `process-compose`
under the hood, so you don't need to remember which `bin/` script does what.

This document describes the pilot surface — today it has one member
(`vm-tpm-microvm`). Build-vm and libvirt members land in follow-on phases.

## Use

```bash
cd ~/repos/ncrmro/ks-config
direnv allow                 # one-time, after the first checkout

devenv up                    # bring up the default fleet, foreground
devenv up -d                 # bring it up detached
devenv up vm-tpm-microvm     # bring up a single named VM
devenv processes down        # tear down everything cleanly
```

## Decision tree

| I want to… | Run |
|---|---|
| Validate TPM 2.0 / LUKS unlock end-to-end (~20 s, Tier 1) | `devenv up vm-tpm-microvm` |
| _build-vm terminal iteration (Tier 2)_ | _coming in phase 2a_ |
| _build-vm desktop iteration (Hyprland, Tier 2)_ | _coming in phase 2a_ |
| _Full libvirt + secureboot + TPM install (Tier 3)_ | _coming in phase 2b — once `keystone/bin/virtual-machine` has SIGTERM handling and dynamic swtpm socket paths_ |

For details on each tier, see `../keystone/docs/testing/`.

## Inspect

`process-compose` is not on the host PATH; it's only available inside the
devenv shell, and the daemon exposes a UDS socket rather than a TCP port. To
list / read logs:

```bash
SOCK=$(find /run/user/$UID -maxdepth 2 -name pc.sock | head -n1)

devenv shell -- process-compose process list \
  -u "$SOCK" --use-uds -o json

devenv shell -- process-compose process logs vm-tpm-microvm \
  -u "$SOCK" --use-uds --tail 200 --log-no-color
```

Avoid `-f` on logs in agent/CI contexts — read with `--tail` instead.

## Extend

To add a new fleet member:

1. Add a `processes.<name>` block to `devenv.nix`. Lean on a `writeShellApplication`
   from `inputs.keystone.packages.${system}` whenever possible so the wrapper
   script's existing lifecycle (traps, swtpm cleanup, etc.) handles teardown.
2. Pick a readiness probe. `pgrep -f <unique-substring>` is fine for microvms;
   SSH-based probes (`ssh -o ConnectTimeout=1 …`) are better for VMs you'll
   interact with.
3. If the underlying script doesn't clean up on SIGTERM, set
   `process-compose.shutdown.command` to do the cleanup explicitly. Otherwise
   process-compose's PID-based termination will leak swtpm sockets and
   libvirt domains.
4. Document the new member in the decision tree above.

## Cross-references

- `../keystone/bin/test-microvm-tpm` — the script wrapped by the
  `vm-tpm-microvm` process.
- `../keystone/tests/flake.nix` — declares
  `packages.${system}.test-microvm-tpm` (a `writeShellApplication`) and the
  `tpm-microvm` `nixosSystem`.
- `../keystone/docs/testing/` — tier model and full reference for the
  underlying scripts.
- `devenv.nix`, `devenv.yaml` — fleet declaration and input pins.
