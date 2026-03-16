# TODO: Migrate root authorized_keys to use only hardware keys via
# keystone.hardwareKey.rootKeys. Consider adding keystone.keys helpers
# like `adminKeys` (all keys for wheel users) and `rootKeys` (hardware-only).
{ lib, config, ... }:
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
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = lib.mkDefault "no";
  };
  users.users."root".openssh.authorizedKeys.keys = allKeysFor "ncrmro";
}
