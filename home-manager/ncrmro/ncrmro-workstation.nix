{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common/features/desktop/obs.nix
    ../common/features/desktop/digital_audio_workstation.nix
    ../common/features/desktop/openscad.nix
  ];

  wayland.windowManager.hyprland.settings = {
    monitor = [
      "desc:LG Electronics LG Ultra HD 0x00044217, 3840x2160@60.00Hz, 0x0, 1"
      "desc:LG Electronics LG Ultra HD 0x000063ED, 3840x2160@60.00Hz, auto-center-left, 1, transform, 1"
    ];
    workspace = [
      "1, monitor:desc:LG Electronics LG Ultra HD 0x000063ED, persistent:true"
      "2, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:true"
      "3, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "4, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "5, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "6, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "7, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "8, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "9, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
      "11, monitor:desc:LG Electronics LG Ultra HD 0x00044217, persistent:false"
    ];
  };

  keystone.terminal.ai.ollama = {
    enable = true;
    host = "http://ncrmro-workstation:11434";
    defaultModel = "qwen3:32b";
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
        sudo nixos-rebuild "$cmd" --flake ~/nixos-config#ncrmro-workstation "$@"
        if [[ "$cmd" == "boot" ]]; then
          echo "Reboot required to apply changes."
        fi
      }
    '';
  };
}
