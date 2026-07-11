# Ocean-specific ncrmro HM config: mail, rebuild function, stateVersion pin.
# Structural imports (terminal, notes, global, cli) are provided by modules/keystone/terminal.nix.
{ config, lib, ... }:
{
  # stateVersion pinned to 25.05 (overrides keystone default from system.stateVersion)
  home.stateVersion = lib.mkForce "25.05";

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
    sync.enable = true;
    # Ocean is the daily-rollover singleton; keystone main defaults
    # daily.enable = false everywhere else.
    daily.enable = true;
  };

  home.file.".kube/config".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/rancher/k3s/k3s.yaml";

  programs.zsh = {
    initContent = ''
      # NixOS rebuild function with --boot support for critical changes
      update() {
        local cmd="switch"
        if [[ "$1" == "--boot" ]]; then
          cmd="boot"
          shift
        fi
        sudo nixos-rebuild "$cmd" --flake ~/repos/ncrmro/ks-config#ocean "$@"
        if [[ "$cmd" == "boot" ]]; then
          echo "Reboot required to apply changes."
        fi
      }
    '';
  };
}
