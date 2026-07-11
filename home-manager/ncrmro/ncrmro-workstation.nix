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

  keystone.terminal.ai.ollama = {
    enable = true;
    host = "http://ncrmro-workstation:11434";
    defaultModel = "qwen3:32b";
  };

  # Workstation uses Hyprland's master layout for the ultrawide monitor.
  # Keep this host-specific; laptops should use Keystone/Hyprland defaults.
  wayland.windowManager.hyprland.settings = {
    general.layout = "master";
    master = {
      new_status = "slave";
      orientation = "center";
      slave_count_for_center_master = 0;
    };
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
        sudo nixos-rebuild "$cmd" --flake ~/repos/ncrmro/ks-config#ncrmro-workstation "$@"
        if [[ "$cmd" == "boot" ]]; then
          echo "Reboot required to apply changes."
        fi
      }
    '';
  };

  # BEGIN keystone-managed desktop state
  # BEGIN keystone-managed monitors
  keystone.desktop.monitors = {
    primaryDisplay = "desc:Dell Inc. DELL U5226KW 9XM3884";
    autoMirror = false;
    settings = [
      "desc:Dell Inc. DELL U5226KW 9XM3884, 6144x2560@120.00, 0x0, 1.00, transform, 0"
    ];
  };
  # END keystone-managed monitors
  # BEGIN keystone-managed audio defaults
  keystone.desktop.audio.defaults = {
    sink = "alsa_output.usb-Loud_Technologies_Inc._Onyx_Blackjack-00.analog-stereo";
    source = "alsa_input.usb-046d_Logitech_BRIO_873172C7-03.analog-stereo";
  };
  # END keystone-managed audio defaults
  # BEGIN keystone-managed printer defaults
  keystone.desktop.printer.default = "Brother_HL_L2395DW_series";
  # END keystone-managed printer defaults
  # END keystone-managed desktop state
}
