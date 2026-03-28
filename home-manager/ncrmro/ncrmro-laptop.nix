{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common/features/desktop/digital_audio_workstation.nix
  ];

  wayland.windowManager.hyprland.settings = {
    monitor = [
      "desc:BOE 0x0BCA, 2256x1504@60.00Hz, auto, 1"
    ];
  };

  programs.zsh = {
    initContent = ''
      # NixOS rebuild function with --boot support for critical changes
      update() {
        local cmd="switch"
        if [[ "$1" == "--boot" ]]; then
          cmd="boot"
          shift
        fi
        sudo nixos-rebuild "$cmd" --flake ~/nixos-config#ncrmro-laptop "$@"
        if [[ "$cmd" == "boot" ]]; then
          echo "Reboot required to apply changes."
        fi
      }
    '';
  };
}
