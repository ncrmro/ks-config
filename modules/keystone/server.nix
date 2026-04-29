# NixOS: server role — enables keystone server module.
#
# `keystone.nixosModules.server` is imported automatically by mkSystemFlake
# when `kind = server` (see mkLinuxHost / linuxKindDefaults). We do not
# re-import it here to keep the desktop/operating-system pattern consistent
# (a second inline-attrset instance is not deduplicated by NixOS and
# duplicates downstream `home-manager.sharedModules` entries).
{ ... }:
{
  keystone.server.enable = true;
}
