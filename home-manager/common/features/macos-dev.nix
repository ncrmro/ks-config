{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # Common macOS development toolkit
  # Shared by all macOS home-manager configurations
  imports = [
    inputs.keystone.homeModules.terminal
    ./cli
    ./cli/git.nix
    ./cli/ssh.nix
    ../optional/mcp/github-mcp.nix
    ../optional/mcp/kubernetes.nix
  ];

  programs.home-manager.enable = true;

  # Do not set home-manager's `nix.settings` here: it writes
  # xdg.configFile."nix/nix.conf", which collides with keystone terminal's
  # home.file.".config/nix/nix.conf" Darwin writer (already enables
  # nix-command + flakes) and fails the managed-target-files assertion.
}
