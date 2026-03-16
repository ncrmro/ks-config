# TODO: Migrate zfs-sync user keys to keystone.keys. Consider adminKeys/rootKeys helpers.
{ pkgs, config, ... }:
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
  # Enable ZFS backup and NAS
  # zfs create -p ocean/backups/maia
  # zfs allow maia-sync ocean/backups/maia
  # zfs allow maia-sync receive,create,mount,readonly ocean/backups/maia
  # zfs set readonly=off ocean/backups/maia

  # Install packages required for ZFS replication
  environment.systemPackages = with pkgs; [
    lzop
    mbuffer
  ];

  users.users.maia-sync = {
    isSystemUser = true;
    shell = pkgs.bash;
    group = "zfs-sync";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCYpB2eDinPg/QrRH6MQXq7SIQpnywmtuFKTAYRibY5Pezkz+eJFYvL/edXID0vo4NeGOGSRtSrPlhICZPnR2U06CFnWG6Wr9qwxIizRG3iMFLVKT9K3ZmXslwBDXYe2Mnnd6KN05DTSUUwCTuUBnTxslfVI3/AU/KkaAinQ9J78i9C4ibPIMPqhgaRum4y3VDWkpJVnuXHLK11fbVKnevP+4KzYuL8/moJCD4sdAmsezdYaNO0Fl+3kPwK0mYmOzWeZTalRAHdPxLSyltIolYHqW8YEWHXP9adUdAaux9Iz22t9Tune9seDT8Jog1iUfwBjiYfw7I4i22XlbNzv14qPYeSiSBpRGzEqYQTdNeJxO91sZrY14MYwq3QVEY5HvtJAtNBbwnhtuZygKNFkK1IGbgvscPxWUWChCrbAFrrYHzQHYHlwOH2drn2CysrvOEEMZK9PKQYY3fKl5TLm0nG78wqR7oo2e816YNR6tDN6ThDgrHI2txtVvHb+ZOOhHM= root@ocean"
    ];
  };

  users.groups.zfs-sync = { };

  users.users.laptop-sync = {
    isSystemUser = true;
    shell = pkgs.bash;
    group = "zfs-sync";
    openssh.authorizedKeys.keys = allKeysFor "ncrmro";
  };
}
