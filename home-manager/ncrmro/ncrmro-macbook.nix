{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../common/global
    ../common/features/macos-dev.nix
    ../common/features/macos-ocean-mounts.nix
    ../common/optional/eternal-terminal.nix
  ];

  home = {
    username = "ncrmro";
    homeDirectory = "/Users/ncrmro";
    stateVersion = "25.05";
  };

  keystone.terminal.ai.enable = false;
  keystone.terminal.deepwork.enable = false;
  keystone.terminal.sandbox.enable = false;
}
