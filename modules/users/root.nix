# TODO: Migrate root authorized_keys to use only hardware keys via
# keystone.hardwareKey.rootKeys. Consider adding keystone.keys helpers
# like `adminKeys` (all keys for wheel users) and `rootKeys` (hardware-only).
{ config, ... }:
let
  keysCfg = config.keystone.keys;
  allKeysFor =
    username:
    let
      u = keysCfg.${username};
      hostKeys = builtins.attrValues (builtins.mapAttrs (_: h: h.publicKey) u.hosts);
      hwKeys = builtins.attrValues (builtins.mapAttrs (_: h: h.publicKey) u.hardwareKeys);
    in
    hostKeys ++ hwKeys;
in
{
  users.users."root".openssh.authorizedKeys.keys = allKeysFor "ncrmro";
}
