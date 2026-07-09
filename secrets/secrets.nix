# agenix recipient policy — evaluated by the agenix CLI, not by hosts.
# Recipients are derived from the key registry in keystone.json so keys
# declared once in keystone.yaml are automatically encryption identities
# for every secret. Hosts decrypt unattended with their software SSH host
# keys (add each host's /etc/ssh/ssh_host_ed25519_key.pub after install);
# hardware keys are the admin-side rekeying identities.
#
# No secrets exist yet: the legacy fleet's secrets live in the private
# agenix-secrets repo encrypted to the old recipient set, and the YubiKeys
# have no age identities enrolled. Both are migration-doc items.
let
  config = builtins.fromJSON (builtins.readFile ../keystone.json);

  # Only keys that declare an ageRecipient participate (device-bound SSH
  # signers are never secrets recipients).
  adminRecipients = builtins.filter (r: r != null) (
    map (k: k.ageRecipient or null) (builtins.attrValues config.keys.hardware)
  );

  hostKeys = [
    # "ssh-ed25519 AAAA... root@ocean"
    # "ssh-ed25519 AAAA... root@ncrmro-laptop"
    # "ssh-ed25519 AAAA... root@ncrmro-workstation"
  ];

  all = adminRecipients ++ hostKeys;
in
{
  # Example (created with `agenix -e vaultwarden-env.age` in this directory):
  # "vaultwarden-env.age".publicKeys = all;
}
