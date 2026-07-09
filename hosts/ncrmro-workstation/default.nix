# Host-specific overrides for `ncrmro-workstation`. Fleet-wide settings live in
# keystone.yaml. Real storage/boot/secure-boot (disko + lanzaboote + TPM)
# arrive with the keystone-systems os flake's mkFleet port; until then this
# host is VM-harness-only. The legacy deployable config is on main at
# hosts/workstation/.
{ ... }:
{
  # Placeholder filesystem so the configuration evaluates before the os
  # flake's disko-managed storage module replaces it.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  boot.loader.systemd-boot.enable = true;

  system.stateVersion = "25.05";
}
