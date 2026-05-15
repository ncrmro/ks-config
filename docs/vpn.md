# VPN (Headscale + Tailscale)

Mercury runs Headscale at `https://mercury.ncrmro.com` (control plane) and DERP
(region 999, "mercury"). All fleet hosts join the tailnet via the keystone OS
module (`modules/os/tailscale.nix` in the `keystone` flake), which sets
`services.tailscale.enable = true` and `extraUpFlags = ["--login-server=…"]`.

Authoritative references:
- Headscale server config: `modules/nixos/headscale/default.nix`
- Client config (fleet-wide): `keystone.os.tailscale` in keystone
- Pre-auth-key autoconnect (agent VMs only): `hosts/common/optional/tailscale-authkey.nix`
- Per-host registry: `hosts.nix` (used by ACL/DNS generation)

DNS via the tailnet uses AdGuard Home on ocean (`100.64.0.6`) and mercury
(`100.64.0.38`), pushed by `services.headscale.settings.dns.override_local_dns
= true`. MagicDNS short names resolve under `*.mercury`.

## Client roles and auth

| Role | How it joins | Notes |
|---|---|---|
| `server` (ocean, mercury, maia) | `services.tailscale.enable` only | Manual `tailscale up` on first boot; key persists in `/var/lib/tailscale/`. Tagged `tag:server` via ACL. |
| `client` (workstation, laptop) | `services.tailscale.enable` only | Manual `tailscale up` on first boot. Owned by `ncrmro@`, no tags. |
| `agent` (VM agents) | `tailscale-authkey.nix` oneshot | Reads agenix-encrypted pre-auth key, auto-registers on boot. Tagged `tag:agent`. |

`client` hosts do **not** import `tailscale-authkey.nix`. After a `tailscale
down` they require a manual `sudo tailscale up --login-server=https://mercury.ncrmro.com
--accept-routes` to come back. The status message "Stopped; run 'tailscale up'
to log in" is misleading — if `tailscale debug prefs` shows `LoggedOut: false`,
the persistent key is intact and no reauth is needed.

## Troubleshooting: one peer's tunnel stays one-way

### Symptom (observed 2026-05-15 on ncrmro-laptop)

After bringing the laptop up, `tailscale status` showed asymmetric counters:

```
mercury     active; relay "dfw",  tx 156 rx 0     <-- broken
ocean       active; direct LAN,   tx 156 rx 0     <-- broken
workstation active; direct LAN,   tx 4516 rx 3644 <-- working
```

Downstream symptoms: `dig` timed out (systemd-resolved was pointed at
`100.64.0.6`/`100.64.0.38` via MagicDNS, both unreachable through the broken
tunnels), `et ocean` failed (name didn't resolve).

### Root cause

Stale WireGuard kernel peer state on the *other* peers. Headscale had the
correct netmap for everyone — ocean's and workstation's `tailscale debug
netmap` showed identical endpoint lists for the laptop's current node key.
But ocean's and mercury's kernel WG sessions for that key never completed a
handshake, so packets went out and nothing came back. Workstation, having
renegotiated recently, was fine.

Contributing factor: the headscale DB record for the laptop is anomalous —
`created_at` is the Go zero value (`-62135596800`) and `register_method` is
null, while sibling records (e.g. `ncrmro-laptop-14`) have both populated.
The record predates a schema change and has been updating in place across
several headscale upgrades. The current node key is fresh; only the metadata
is stale. This didn't directly cause the wedge, but is consistent with the
node being a long-lived special case (it also holds the very first tailnet
IP, `100.64.0.1`).

### Diagnosis path

1. From the affected host, confirm the daemon is up and authenticated:
   ```
   tailscale debug prefs | grep -E 'WantRunning|LoggedOut|ControlURL'
   ```
   `LoggedOut: false` means the key is still good; no reauth needed.

2. Compare `tailscale debug netmap` between the affected host and a working
   peer. If endpoint lists for the affected host are identical, netmap
   propagation is fine and the issue is in the kernel WG state, not headscale.

3. From a working peer (e.g. workstation, ocean), query its view of the
   affected host:
   ```
   tailscale status --json | jq '.Peer[] | select(.HostName=="<host>")'
   ```
   `LastHandshake: "0001-01-01T00:00:00Z"` and `TxBytes/RxBytes: 0` confirm
   the kernel session never established.

4. Verify headscale agrees the node is registered:
   ```
   ssh root@216.128.136.32 'headscale nodes list'
   ```
   Use the VPS IP, not `mercury.ncrmro.com` — that hostname resolves to
   Cloudflare and SSH won't go through.

### Fix

Restart `tailscaled` on the peers that have the wedged session (in this case,
mercury and ocean):

```
ssh root@216.128.136.32 'systemctl restart tailscaled'
ssh ncrmro@192.168.1.10  'sudo systemctl restart tailscaled'
```

Then on the affected host:

```
sudo tailscale up --login-server=https://mercury.ncrmro.com --accept-routes
```

Within a few seconds `tailscale status` should show non-zero `rx` from both
peers and `ping 100.64.0.6` / `ping 100.64.0.38` should work.

### Last-resort: re-register the node

If kernel-state flush doesn't fix it, the headscale node record itself may
be corrupted. Wipe and re-register:

```
# on affected host
sudo tailscale logout

# on mercury
headscale nodes delete <id>
headscale preauthkeys create --user ncrmro --reusable --expiration 1h

# on affected host
sudo tailscale up --login-server=https://mercury.ncrmro.com \
  --authkey=<key> --accept-routes
```

The node will get a fresh tailnet IP (next available). Nothing in this repo's
configs references client tailnet IPs directly — only `100.64.0.6` (ocean)
and `100.64.0.38` (mercury) appear in `headscale/default.nix` `extra_records`
and the AdGuard config — so re-registering a client is safe. Re-registering
a `tag:server` host would require updating those references.

## Why MagicDNS breaking takes the whole machine offline

When tailscale is up, `tailscaled` replaces systemd-resolved's per-link DNS
with the tailnet resolvers (mercury + ocean). If the tunnels to those two
are broken, every DNS query hangs, even for public names. With tailscale
down, the LAN DHCP DNS server (ocean's LAN IP `192.168.1.10`, also running
AdGuard) takes over and resolution recovers.

Temporary workaround while debugging a broken tunnel — keep LAN DNS while
the tailnet is up:

```
sudo tailscale up --login-server=https://mercury.ncrmro.com \
  --accept-routes --accept-dns=false
```

You lose MagicDNS short names (`ssh ocean` won't work, `ssh 100.64.0.6` will).
