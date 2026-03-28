# NixOS: server role — enables keystone server module.
{ inputs, ... }:
{
  imports = [
    inputs.keystone.nixosModules.server
  ];

  keystone.server.enable = true;
}
