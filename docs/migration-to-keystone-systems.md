# Migration to keystone-systems

Date: 2026-07-08

This branch cuts the repo over to the keystone-systems flakes and the
shared-config template (keystone.yaml → keystone.json → `lib/mkConfig.nix`).
Everything the legacy flake provided was **dropped, not ported** — this
document is the ledger. All removed code remains on `main` and in git
history; nothing here is lost, only deferred.

**Headline caveat: this branch cannot deploy the real hosts.** Host dirs
carry placeholder tmpfs roots until the keystone-systems os flake's
mkFleet port lands (disko storage, lanzaboote Secure Boot, TPM unlock —
see keystone-systems/os `worktree-req-001-foundation`). Verification is
VM-harness-only (`nix run .#fleet`, docs/vm-fleet.md). `main` remains the
deployable flake until this branch reaches parity.

## Dropped inputs

| Input | What it did | Replacement / plan |
| --- | --- | --- |
| `keystone` (ncrmro/keystone `milestone/M10-V2-os-agents`) | mkSystemFlake fleet: kinds, storage, secure boot, TPM, installer ISO, update channels, zram, users/capabilities | keystone-systems os flake; full-stack path pending REQ-001 merge |
| `agenix-secrets` (private, git.ncrmro.com) | per-host secrets, ncrmro SSH key autoload, service credentials | local `./secrets` agenix dir (empty). Migrate: enroll age-plugin-yubikey identities for yubi-black/green, re-encrypt needed secrets to the new recipient set, add host keys post-install |
| `vega` | OS-agent bridge packages + Plouton/Vega OCI container workloads | not in new stack yet — needs a keystone-systems services-flake story for OCI/container workloads |
| `llm-agents` | pi and agent packages | reintroduce via terminal flake `extraPackages` or a dedicated agents flake |
| `llama-cpp` | workstation LLM serving (MXFP4) | per-host module once host-specific modules return |
| `nixos-hardware` | hardware quirks (framework laptop etc.) | returns with real host configs |

## Dropped trees (all on `main`)

- `hosts/` — real host configs. Per host:
  - **ocean**: k3s + storage classes, forgejo-runner, adguard-home,
    disko ZFS, immich (immich itself now comes from the services flake;
    k3s/runner/adguard do not exist in the new stack yet).
  - **maia**: zpool `lake`, wireguard, k3s worker, disko — *host not in
    new fleet yet* (add to keystone.yaml when storage story lands).
  - **mercury**: Vultr VPS (`server-vm` kind), adguard-home, nginx —
    *host not in new fleet*; new stack has no cloud-image kind.
  - **catalystPrimary**: documented non-keystone k3s exception —
    *dropped from this repo's scope*.
  - **workstation/ncrmro-laptop**: hardware-configuration + disko ZFS —
    return with the os flake storage port.
- `modules/` — nixos + home-manager module libraries, keys registry
  (keys now live in keystone.yaml), keystone-spike (portable devbox).
- `overlays/`, `packages/` — `pkgs.keystone.*` (claude-code, codex,
  gemini-cli, zesh), mcp-language-server, devbox image, installer ISO
  output.
- `agents/` — agent identities/capabilities (drago, luce, applepi) tied
  to the legacy keystone user/capability schema and vega bridge.
- `home-manager/` — macOS homeConfigurations (`nicholas@unsup-macbook`,
  `ncrmro@ncrmro-macbook`). keystone.yaml declares `ncrmro-macbook`
  (kind macbook, aerospace) but the template has no darwin support yet.
- `kubernetes/` — cluster manifests. keystone.yaml keeps the `homelab`
  cluster declaration; the services flake's kubernetes frontdoor is not
  enabled yet.
- `secrets/` (stalwart mail passwords — encrypted to old recipients),
  `secrets.nix`, `hosts.nix`, `repos.nix`, `bin/`, `spikes/`, `archive/`.

## Behavior changes

- nixpkgs: `nixos-unstable` → pinned `nixos-25.05` (matches the
  keystone-systems stack; `defaults.updateChannel` in keystone.yaml is
  declarative-only until the os flake port consumes it).
- TLS: legacy fleet served real certificates; `services.tls = "none"`
  until acme-dns credentials migrate into `./secrets`.
- zram, sshAutoLoad, capabilities, per-host specialArgs (mercury reading
  ocean's config): all legacy-keystone features with no equivalent yet.
- CI (`nix flake check`): no longer blocked on the private agenix-secrets
  fetch, but the absolute `path:` inputs for services/terminal/desktop
  cannot resolve on GitHub runners — verify stays red until those repos
  publish and the inputs flip to `github:keystone-systems/*`.

## Parity checklist before main can be retired

1. keystone-systems/os REQ-001 merge + mkFleet/mkConfigFlake port
   (storage, Secure Boot, TPM, installer ISO, Headscale).
2. Secrets migration (yubikey age identities → re-encrypt → host keys).
3. k3s / container-workload story (ocean cluster, vega/plouton, runner).
4. maia + mercury host coverage (storage server, cloud-image kind).
5. Darwin support for ncrmro-macbook.
6. Publish keystone-systems repos and drop absolute `path:` inputs.
