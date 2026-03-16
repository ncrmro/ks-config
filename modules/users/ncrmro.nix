{ config, ... }:
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
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.users.ncrmro = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ]
    ++ ifTheyExist [
      "media"
      "audio"
      "input"
      "networkmanager"
      "sound"
      "docker"
      "podman"
      # dialout grants access to serial ports (/dev/ttyUSB*, /dev/ttyACM*)
      # required for ESP32, Arduino, and other microcontroller development
      "dialout"
    ];
    openssh.authorizedKeys.keys = allKeysFor "ncrmro";
  };
}
