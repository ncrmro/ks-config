# NixOS: desktop role — HM boilerplate + desktop HM modules for ncrmro.
# Does NOT import terminal.nix because homeModules.desktop already imports
# modules/terminal (directory) internally via modules/desktop/home/default.nix.
# Importing homeModules.terminal (explicit file path) alongside would cause a
# duplicate option declaration conflict.
{ inputs, outputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.default
    # TODO(upstream-keystone): drop once milestone fix 2d12ae01 lands on main.
    ./desktop/greetd-session.nix
    # `keystone.nixosModules.desktop` is imported automatically by
    # mkSystemFlake when `kind = laptop` or `kind = workstation`. Re-importing
    # it here from `inputs.keystone.nixosModules.desktop` produces a second
    # inline-attrset instance that NixOS does not deduplicate; the desktop
    # module's `home-manager.sharedModules = [ self.homeModules.desktop ]`
    # then runs twice and triggers `programs.walker.elephant` "already
    # declared" errors during home-manager evaluation.
  ];

  users.mutableUsers = true;

  # bitwarden-desktop in nixpkgs (2026.5.0) still pins electron 39, which is
  # now flagged insecure. Upstream is mid-migration (bitwarden/clients#20448).
  # Accept the warning until that PR lands and nixpkgs rebases on electron 40+.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit inputs outputs; };

  keystone.desktop = {
    enable = true;
    user = "ncrmro";
  };

  # Desktop needs resolved for Tailscale MagicDNS
  keystone.os.services.resolved.enable = true;

  keystone.os.users.ncrmro.desktop.enable = true;

  # ncrmro HM modules for desktop hosts.
  # keystone.nixosModules.operating-system provides terminal and notes as
  # sharedModules. keystone.nixosModules.desktop provides desktop. Do NOT
  # re-import any of these here.
  home-manager.users.ncrmro.imports = [
    ../../home-manager/common/global
    ../../home-manager/common/features/cli
    ../../home-manager/common/features/desktop
    ../../home-manager/common/features/virtualization.nix
    ../../home-manager/common/features/cliflux.nix
    ../../home-manager/common/optional/mcp/github-mcp.nix
    ../../home-manager/common/optional/mcp/kubernetes.nix
    ../../home-manager/ncrmro/base.nix
    ./desktop/experimental
  ];
}
