# VM fleet

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
