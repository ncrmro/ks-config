# Secrets

Encrypted agenix files consumed by fleet services. Recipients come from the
hardware key registry in `keystone.yaml` (see `secrets.nix`): every
`keys.hardware.*.ageRecipient` can decrypt every secret. Enroll and validate
those recipients per `docs/hardware-keys.md` — until at least one hardware
key has an `ageRecipient`, no admin-side identity can create or rekey
secrets (`scripts/validate-hardware-keys.sh` flags this).

Create or edit a secret:

```sh
cd secrets
agenix -e vaultwarden-env.age
```

Enabling a service in `keystone.yaml` whose required secret file is missing
here fails at evaluation time with a message naming the file to create. The
catalog of required secrets lives in `services/lib/catalog.nix`:

| Secret | Required by | Contents |
| --- | --- | --- |
| `vaultwarden-env.age` | `services.vaultwarden` | `ADMIN_TOKEN=...` |
| `acme-dns-credentials.age` | `services.tls = "acme-dns"` | `CLOUDFLARE_DNS_API_TOKEN=...` |

After installing a host, append its `/etc/ssh/ssh_host_ed25519_key.pub` to
`hostKeys` in `secrets.nix` and run `agenix -r` to rekey.
