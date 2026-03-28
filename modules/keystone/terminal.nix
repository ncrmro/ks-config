# NixOS: home-manager infrastructure + ncrmro base terminal HM config.
# Used by all hosts where ncrmro needs a terminal environment (servers + desktops).
# Desktop hosts import desktop.nix instead, which imports this file.
{ inputs, outputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.default
  ];

  users.mutableUsers = true;
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit inputs outputs; };

  # Base ncrmro home-manager config: terminal tools + notes (no desktop)
  home-manager.users.ncrmro.imports = [
    inputs.keystone.homeModules.terminal
    inputs.keystone.homeModules.notes
    ../../home-manager/common/global
    ../../home-manager/common/features/cli
  ];
}
