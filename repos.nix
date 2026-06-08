{
  "ncrmro/ks-config" = {
    url = "git@github.com:ncrmro/ks-config.git";
  };
  "ncrmro/keystone" = {
    url = "git@github.com:ncrmro/keystone.git";
    # Do not set flakeInput here: ks-config pins Keystone to the remote
    # milestone branch in flake.lock. A local checkout at ../keystone is often
    # on main, and ks update's local override would otherwise shadow the lock
    # with that checkout and drop milestone-only options.
  };
  "ncrmro/agenix-secrets" = {
    url = "ssh://forgejo@git.ncrmro.com:2222/ncrmro/agenix-secrets.git";
    flakeInput = "agenix-secrets";
  };
}
