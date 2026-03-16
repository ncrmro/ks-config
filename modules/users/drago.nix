{ config, pkgs, ... }:
let
  keysCfg = config.keystone.keys;
  allKeysFor =
    username:
    let
      u = keysCfg.${username};
      hostKeys = builtins.attrValues (builtins.mapAttrs (_: h: h.publicKey) u.hosts);
      hwKeys = builtins.attrValues (builtins.mapAttrs (_: h: h.publicKey) u.hardwareKeys);
    in
    hostKeys ++ hwKeys;
in
{
  programs.zsh.enable = true;

  users.users.drago = {
    isNormalUser = true;
    description = "Autonomous Agent";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    initialPassword = "password"; # For testing, change later
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = allKeysFor "ncrmro";
  };
}
