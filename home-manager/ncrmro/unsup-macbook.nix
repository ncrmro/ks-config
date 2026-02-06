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

  programs.home-manager.enable = true;
}
