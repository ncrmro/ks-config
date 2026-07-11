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
  # instead of the stale Claude plugin copy.
  keystone.terminal.ai.enable = false;
  keystone.terminal.deepwork.enable = true;
  keystone.terminal.sandbox.enable = false;

  # Outfitter settings/profiles are linked from agents/outfitter by the shared
  # Home Manager config imported above.
  programs.home-manager.enable = true;
}
