{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../common/global
    ../common/features/macos-ocean-mounts.nix
    inputs.keystone.homeModules.terminal
  ];

  home = {
    username = "nicholas";
    homeDirectory = "/Users/nicholas";
    stateVersion = "25.05";
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };
  };

  home.packages = with pkgs; [
    kubectl
    k9s
  ];

  # CLI AI tools (claude-code/gemini/codex) come from elsewhere on this machine,
  # so keep the keystone AI stack off — but run the keystone-pinned DeepWork MCP
  # and the Pi assistant (both decoupled from ai.enable upstream) instead of the
  # stale Claude plugin copy.
  keystone.terminal.ai.enable = false;
  keystone.terminal.deepwork.enable = true;
  keystone.terminal.pi.enable = true;
  keystone.terminal.sandbox.enable = false;

  # Enable bridl so the agent context profiles are installed on this laptop.
  # configDir must be set explicitly: in standalone-HM mode the module defaults
  # to ~/repos/ks-config, but this checkout lives under ~/repos/ncrmro/ks-config.
  keystone.terminal.bridl.enable = true;
  keystone.terminal.bridl.configDir = "${config.home.homeDirectory}/repos/ncrmro/ks-config/agents/bridl";

  programs.home-manager.enable = true;
}
