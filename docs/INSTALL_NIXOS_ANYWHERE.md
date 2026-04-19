# Installing NixOS with nixos-anywhere

This document provides instructions for installing NixOS using nixos-anywhere, including preparation steps, installation commands, and post-installation tasks.

## Requirements
- Nix with flakes enabled
- For remote installs: SSH access as root to the target host
- For ZFS systems: a stable networking host ID

## Useful one-liners
```bash
# Lock flake inputs
nix flake lock

# Tools for installation and disk ops
nix profile add nixpkgs#nixos-install-tools

# Generate a generic hardware config without filesystems (dry-run/rooted)
nixos-generate-config --root /tmp/config --no-filesystems
```

## Generate a host ID (ZFS)
ZFS-based systems require a networking host ID.
```bash
head -c 8 /etc/machine-id 2>/dev/null || head -c 8 /proc/sys/kernel/random/uuid | tr -d '-'
```
Set this in your host config as needed.

## Install with nixos-anywhere
Docs: `github:nix-community/nixos-anywhere`

- VM test install (local emulated install of a host):
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#ncrmro-laptop --vm-test
```

- Remote host install (replace values accordingly):
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#test-vm \
  --generate-hardware-config nixos-generate-config ./hosts/test-vm/hardware-configuration.nix \
  root@192.168.122.62
```

The installer will hang after completing, run this command on the install host

```bash
cryptsetup luksClose /dev/mapper/credstore
```

## Verify Install 

At this point you should have to put you disk encryption password in after the reboot. Confirm you have SSH connectivity.

Note that `ssh-keygen -R IP_ADDRESS` will need to run now that the host's key fingerprint has changed.

Ensure the user can upgrade with flakes:
```bash
nixos-rebuild switch --flake .#devbox --target-host "$HOST"
```


## Next Steps

After installation, complete these tasks and see the guides for additional configuration:

- Turn off emergency access
- [Root Disk TPM + Secure Boot Unlock](./ROOT_DISK_TPM_SECURE_BOOT_UNLOCK.md)
- [Connecting Tailscale Clients](./HEADSCALE_SETUP.md#connecting-tailscale-clients)
- [Fingerprint Enrollment](./fingerprint-enrollment.md)
- [ZFS Tweaks](./zfs-tweaks.md)
- [Mounting Old Disks](./mounting-old-disks.md)

## Updating or deploying to a host
Replace host and address as appropriate.
```bash
# Deploy to a remote host using the flake host
nixos-rebuild switch --flake .#testbox --target-host "root@192.168.1.123"
```

## Home Manager
Switch user configuration via Home Manager (adjust user/host):
```bash
home-manager switch --flake /etc/nixos/flake/#ncrmro@ncrmro-workstation
```

