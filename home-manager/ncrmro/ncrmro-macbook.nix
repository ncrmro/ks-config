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

  # macOS-specific configurations can be added here
  # For example:
  # programs.alacritty.settings.font.size = lib.mkForce 14.0;
}
