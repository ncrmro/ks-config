# bridl is BSL-licensed (unfree); allow it on every host that consumes
# the keystone overlay, since keystone.terminal.bridl defaults to enabled
# for all OS agents.
{ lib, ... }:
{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "bridl" ];
}
