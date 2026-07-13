{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  home.username = lib.mkDefault "ncrmro";
  home.homeDirectory = lib.mkDefault "/home/ncrmro";
  home.stateVersion = lib.mkDefault "25.05";

  programs.home-manager.enable = true;

  home.packages = [ pkgs.lsof ];

  # Keep Outfitter's user-editable settings/profile source in ks-config while
  # leaving ~/.outfitter/cache as normal mutable runtime state.
  home.file.".outfitter/settings.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/ncrmro/ks-config/agents/outfitter/settings.yml";
  home.file.".outfitter/profiles".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/ncrmro/ks-config/agents/outfitter/profiles";
  keystone.terminal.applepi.enable = false;

  home.shellAliases = {
    killport = "function _killp(){ lsof -nti:$1 | xargs kill -9 };_killp";
  };

  # Enable Wayland support for Electron/Chromium applications
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  programs.ssh = {
    enable = true;
    # extraConfig = ''
    #   Host *
    #     IdentityAgent ~/.1password/agent.sock
    # '';
  };

  keystone.development = lib.mkDefault true;
  keystone.repos = import ../../../repos.nix;

  # Keystone terminal configuration
  keystone.terminal = {
    enable = true;
    git = {
      userName = "Nicholas Romero";
      userEmail = "ncrmro@gmail.com";
      forgejo = {
        enable = true;
        domain = "git.ncrmro.com";
        sshPort = 2222;
        username = "ncrmro";
      };
    };
    sandbox = {
      extraSubstituters = [ "https://cache.ncrmro.com/main" ];
      extraTrustedPublicKeys = [ "main:H852yjGdbbRIOQcnKm3uZOpZWRFmQoQ5p4I7VDz7kAI=" ];
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Nicholas Romero";
      email = "ncrmro@gmail.com";
    };
    # settings = {
    #   credential.helper = "store";
    #   push.autoSetupRemote = true;
    #   gpg.format = "ssh";
    #   commit.gpgsign = true;
    #   user.signingkey = "~/.ssh/id_ed25519";
    #   lfs.enable = true;
    #   alias = {
    #     b = "branch";
    #     p = "pull";
    #     co = "checkout";
    #     c = "commit";
    #     ci = "commit -a";
    #     a = "add";
    #     st = "status -sb";
    #   };
    # };
  };
}
