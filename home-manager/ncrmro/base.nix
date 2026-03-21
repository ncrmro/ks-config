{
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.keystone.homeModules.desktop
    inputs.keystone.homeModules.notes
    ../common/global
    ../common/features/cli
    ../common/features/desktop
    ../common/features/virtualization.nix
    ../common/features/cliflux.nix
    ../common/optional/mcp/github-mcp.nix
    ../common/optional/mcp/kubernetes.nix
    # ../common/optional/mcp/mcp-language-server.nix # GitHub 502, uses rev="main"
  ];

  home.packages = with pkgs; [
    nixfmt
    keystone.google-chrome
    zig
    gh
    gh-dash
    # devcontainer # broken in nixpkgs unstable (node-gyp offline build)
    obsidian
    signal-desktop
  ];

  keystone.terminal.ageYubikey = {
    enable = true;
    identities = [
      {
        serial = "36854515";
        identity = "AGE-PLUGIN-YUBIKEY-17DDRYQ5ZFMHALWQJTKHAV";
      } # yubi-black
      {
        serial = "36862273";
        identity = "AGE-PLUGIN-YUBIKEY-1G9UNYQ5ZJKDT4CQZ8927Z";
      } # yubi-green
    ];
    secretsFlakeInput = "agenix-secrets";
  };

  # CRITICAL: exec-once MUST go in extraConfig, NOT in settings.
  # The hyprland HM settings type is a raw freeform valueType — setting
  # exec-once in settings silently REPLACES keystone's entire exec-once list,
  # which breaks: lock screen on boot (hyprlock), D-Bus activation environment,
  # hyprsunset, hyprpolkitagent, and clipboard manager (clipse).
  wayland.windowManager.hyprland.extraConfig = ''
    exec-once = hyprctl dispatch workspace 2
  '';

  wayland.windowManager.hyprland.settings = {
    windowrule = [
      # Tag messaging apps
      "tag +messaging, match:class Signal"
      "tag +messaging, match:title .*WhatsApp.*"
      "tag +messaging, match:class discord"
      "tag +messaging, match:class telegram"

      # Apply rules to all messaging apps
      "no_screen_share on, match:tag messaging"
      "workspace special:magic, match:tag messaging"
      # "tile, match:tag messaging"

      "workspace special:magic, match:title .*YouTube Music.*"
      # "tile, match:title .*YouTube Music.*"
    ];
  };
  programs.fastfetch.enable = true;

  programs.git.settings = {
    credential.helper = "store";
    includeIf."gitdir:~/code/unsupervised/" = {
      path = "~/code/unsupervised/.gitconfig";
    };
  };

  keystone.terminal.mail = {
    enable = true;
    accountName = "ncrmro";
    email = "nicholas.romero@ncrmro.com";
    displayName = "Nicholas Romero";
    login = "ncrmro";
    host = "mail.ncrmro.com";
    passwordCommand = "cat /run/agenix/stalwart-mail-ncrmro-password";
  };

  keystone.notes = {
    enable = true;
    repo = "ssh://forgejo@git.ncrmro.com:2222/ncrmro/notes.git";
    zk.enable = true;
  };

  keystone.terminal.calendar.enable = true;
  keystone.terminal.contacts.enable = true;
  keystone.terminal.timer.enable = true;
}
