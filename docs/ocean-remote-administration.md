# Ocean SSH administration rollout

The feature branch declares `macbook` as a runtime-enrollable administrator slot, `ocean-k3s-status` as a read-only exact command, and `ocean-k3s-restart` as a predefined durable systemd template. Its standalone remote-administration module is locked from `ks.systems/os`; it reuses the consumer's existing privileged approval catalog. Restricted keys never enter normal user/root key aggregation.

Deployment is **not activated**. Evaluation currently fails in the existing `modules/keystone/os.nix` import of `inputs.keystone.nixosModules.binaryCacheClient`: the locked legacy input does not export it. Fix that fleet dependency mismatch and complete evaluation/build before activation. Do not replace the entire fleet OS input as an incidental enrollment change.

After successful build and the OS PR's acceptance checks, an existing administrator may test Ocean's configuration, enroll the physical Mac's displayed OpenSSH public key using `sudo keystone-admin --enroll macbook < device.pub`, and connect with the native app using `ks-admin-macbook` and the trusted host public key. Runtime enrollment persists across rebuilds. Root revocation is `sudo keystone-admin --revoke macbook`, terminating the slot's active SSH sessions. Use separate slots for additional devices.

First test capabilities, live inventory and the read-only status action. Observe Secure Enclave authentication and credential persistence on physical Apple hardware before enabling a production workflow. Never enroll the development VM's software fixture on Ocean. Leave the existing HTTP service and laptop tunnel running until production SSH acceptance succeeds; preserve their recovery state when retiring them.

The dedicated workstation VM passed native-client SSH interoperability, exact root proof, durable job reconnect, pin/key rejection, enrollment persistence and active-session revocation. Its original cold checkpoint was restored after testing. Ocean has not been reinstalled, repartitioned or had disk keys changed. Maia is untouched. Android/YubiKey clients and remote unlock are future acceptance work.
