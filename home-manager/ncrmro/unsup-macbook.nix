{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../common/global
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

  # AI tools and DeepWork are provided by the Claude Code plugin on this machine
  keystone.terminal.ai.enable = false;
  keystone.terminal.deepwork.enable = false;
  keystone.terminal.sandbox.enable = false;

  programs.home-manager.enable = true;
}
