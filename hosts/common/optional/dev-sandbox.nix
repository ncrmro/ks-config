# Opt-in shim for the devbox spike. Imports the NixOS-side module from
# modules/dev-sandbox/. Promotes to a `keystone.devSandbox.enable = true`
# one-liner once the module lives in keystone proper.
{
  imports = [ ../../../modules/dev-sandbox/os.nix ];
  keystone.devSandbox.enable = true;
}
