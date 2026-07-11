# TODO(upstream-keystone): modules/desktop/nixos.nix — carries milestone fix
# 2d12ae01 (hyprland initial_session + agreety fallback) until it lands on
# keystone main.
#
# CRITICAL: use initial_session for autologin. default_session is the greeter
# session and can register as Class=greeter, which prevents logind from
# handing DRM devices to Hyprland and breaks active-user polkit checks.
# default_session is kept as an agreety fallback for the case where
# initial_session fails before autologin succeeds.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.keystone.desktop;
  hyprlandCmd = "env XDG_SESSION_CLASS=user uwsm start -F ${config.programs.hyprland.package}/bin/Hyprland";
in
{
  config = lib.mkIf cfg.enable {
    services.greetd.settings = {
      default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd '${hyprlandCmd}'";
        # mkForce: upstream assigns cfg.user at normal priority.
        user = lib.mkForce "greeter";
      };
      initial_session = {
        command = hyprlandCmd;
        user = cfg.user;
      };
    };
  };
}
