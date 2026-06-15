{
  lib,
  pkgs,
  ...
}:
{
  programs.ssh = {
    enable = true;
    # Disable deprecated default config
    enableDefaultConfig = false;
    matchBlocks = {
      "unsup-laptop.local" = {
        user = "nicholas";
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      "unsup-air.local" = {
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      "ncrmro-laptop-14" = {
        setEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
