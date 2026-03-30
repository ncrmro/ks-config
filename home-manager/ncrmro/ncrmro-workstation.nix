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

  wayland.windowManager.hyprland.settings.workspace = [
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

  # BEGIN keystone-managed desktop state
  # BEGIN keystone-managed monitors
  keystone.desktop.monitors = {
    primaryDisplay = "desc:LG Electronics LG Ultra HD 0x00044217";
    autoMirror = false;
    settings = [
      "desc:LG Electronics LG Ultra HD 0x00044217, 3840x2160@60.00, 0x0, 1.00, transform, 0"
      "desc:LG Electronics LG Ultra HD 0x000063ED, 3840x2160@60.00, -2160x-840, 1.00, transform, 1"
    ];
  };
  # END keystone-managed monitors
  # BEGIN keystone-managed audio defaults
  keystone.desktop.audio.defaults = {
    sink = "alsa_output.usb-Loud_Technologies_Inc._Onyx_Blackjack-00.analog-stereo";
    source = "alsa_input.usb-046d_Logitech_BRIO_873172C7-03.analog-stereo";
  };
  # END keystone-managed audio defaults
  # END keystone-managed desktop state
}
