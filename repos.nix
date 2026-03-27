{
  "ncrmro/nixos-config" = {
    url = "git@github.com:ncrmro/nixos-config.git";
  };
  "ncrmro/keystone" = {
    url = "git@github.com:ncrmro/keystone.git";
    flakeInput = "keystone";
  };
  "ncrmro/agenix-secrets" = {
    url = "ssh://forgejo@git.ncrmro.com:2222/ncrmro/agenix-secrets.git";
    flakeInput = "agenix-secrets";
  };
}
