# Opt-in shim for the devbox spike (home-manager side). Promotes to a
# `keystone.terminal.devbox.enable = true` one-liner after refactor.
{
  imports = [ ../../../modules/dev-sandbox/home.nix ];
  keystone.terminal.devbox.enable = true;
}
