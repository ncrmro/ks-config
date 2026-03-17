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
    ../common/global
    inputs.keystone.homeModules.desktop
  ];

  # Enable desktop
  keystone.desktop.enable = true;
  keystone.desktop.hyprland.enable = true;

  # Override monitor config for VM (single virtual display)
  wayland.windowManager.hyprland.settings = {
    monitor = [ "Virtual-1, 1920x1080@60, 0x0, 1" ];
    workspace = [ "1, monitor:Virtual-1" ];
    cursor = {
      no_hardware_cursors = true;
    };
  };

  # Disable fingerprint auth in VM - no biometric hardware
  programs.hyprlock.settings.auth.fingerprint.enabled = lib.mkForce false;

  # Basic git config
  programs.git = {
    enable = true;
    userName = lib.mkForce "ncrmro";
    userEmail = lib.mkForce "ncrmro@example.com";
  };

  # Home Manager state version
  home.stateVersion = "24.05";
}
