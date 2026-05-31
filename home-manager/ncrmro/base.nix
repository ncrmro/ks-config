# ncrmro personal HM settings: mail, calendar, contacts, timer, yubikey, git,
# hyprland rules, and packages. Structural imports (terminal, desktop, cli, etc.)
# are provided by modules/keystone/desktop.nix via the NixOS module system.
{
  config,
  pkgs,
  lib,
  ...
}:
{

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
    windowrule = lib.mkDefault [
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

  home.sessionVariables = {
    IMMICH_URL = "https://photos.ncrmro.com";
  };

  programs.zsh.initExtra = ''
    if [ -f /run/agenix/ncrmro-immich-api-key ]; then
      export IMMICH_API_KEY="$(tr -d '\n' < /run/agenix/ncrmro-immich-api-key)"
    fi

    # Prepend ks-config's user-editable DeepWork jobs ahead of the upstream
    # discovery set so locally-tweaked jobs win on name collisions (first
    # match wins per REQ-015 edge cases). Base list is set by
    # keystone.terminal.deepwork; we only extend it here. See
    # ~/repos/ncrmro/ks-config/deepwork/README.md.
    if [ -d "$HOME/repos/ncrmro/ks-config/deepwork/jobs" ]; then
      if [ -n "''${DEEPWORK_ADDITIONAL_JOBS_FOLDERS:-}" ]; then
        export DEEPWORK_ADDITIONAL_JOBS_FOLDERS="$HOME/repos/ncrmro/ks-config/deepwork/jobs:$DEEPWORK_ADDITIONAL_JOBS_FOLDERS"
      else
        export DEEPWORK_ADDITIONAL_JOBS_FOLDERS="$HOME/repos/ncrmro/ks-config/deepwork/jobs"
      fi
    fi
  '';

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
    daily.enable = true;
  };

  keystone.terminal.aiExtensions.enable = true;
  keystone.terminal.calendar.enable = true;
  keystone.terminal.contacts.enable = true;
  keystone.terminal.timer.enable = true;
}
