{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.smb-backup-shares;
in
{
  options.services.smb-backup-shares = {
    enable = lib.mkEnableOption "SMB backup shares";

    backupsRoot = lib.mkOption {
      type = lib.types.str;
      description = ''
        ZFS dataset root for backup shares. This should be the dataset path
        (e.g., "ocean/backups") which will be converted to the filesystem
        mount point by prepending "/" (e.g., "/ocean/backups").
      '';
    };

    timeMachinePasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to agenix-encrypted file containing the Time Machine samba password";
    };

    timeMachineQuota = lib.mkOption {
      type = lib.types.str;
      default = "500G";
      description = "ZFS quota for Time Machine backup dataset";
    };

    windowsBackupQuota = lib.mkOption {
      type = lib.types.str;
      default = "1T";
      description = "ZFS quota for Windows backup dataset";
    };

    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "100.64.0.0/10"
        "192.168.1.0/24"
        "127.0.0.1"
      ];
      description = "List of networks allowed to access SMB shares";
    };

    netbiosName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "NetBIOS name for Samba server. Defaults to system hostname.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Samba with full feature set for backup shares
    # FIXME: Using regular samba instead of samba4Full due to upstream nixpkgs
    # issue where sphinx 9.1.0 doesn't support Python 3.11 (samba4Full dependency)
    services.samba = {
      enable = true;
      # package = pkgs.samba4Full; # Includes Avahi support
      openFirewall = true;

      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "NixOS NAS";
          "netbios name" = cfg.netbiosName;
          "security" = "user";
          "hosts allow" = lib.concatStringsSep " " cfg.allowedNetworks;
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "bad user";

          # Security settings
          "server smb encrypt" = "required";
          "server min protocol" = "SMB3_00";

          # macOS compatibility
          "fruit:aapl" = "yes";
          "fruit:nfs_aces" = "no";
          "fruit:copyfile" = "no";
          "fruit:model" = "MacSamba";
        };

        # Time Machine backup share
        "timemachine" = {
          # Convert ZFS dataset path to filesystem mount point by prepending "/"
          "path" = "/${cfg.backupsRoot}/timemachine";
          "valid users" = "timemachine";
          "force user" = "timemachine";
          "force group" = "timemachine";
          "read only" = "no";
          "browseable" = "yes";
          "create mask" = "0600";
          "directory mask" = "0700";

          # Time Machine specific settings
          "fruit:time machine" = "yes";
          "fruit:time machine max size" = cfg.timeMachineQuota;
          "vfs objects" = "catia fruit streams_xattr";
        };

        # Windows backup share
        "windows-backup" = {
          # Convert ZFS dataset path to filesystem mount point by prepending "/"
          "path" = "/${cfg.backupsRoot}/windows";
          "valid users" = "backup";
          "force user" = "backup";
          "force group" = "backup";
          "read only" = "no";
          "browseable" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
          "vfs objects" = "catia streams_xattr";
        };

        # macOS-friendly media share. Reuses the Time Machine SMB credential
        # but forces filesystem access through the existing media user/group.
        "media" = {
          "path" = "/ocean/media";
          "valid users" = "timemachine";
          "force user" = "media";
          "force group" = "media";
          "read only" = "no";
          "browseable" = "yes";
          "create mask" = "0664";
          "directory mask" = "0775";
          "vfs objects" = "catia fruit streams_xattr";
        };
      };
    };

    # Enable Samba Web Service Discovery for Windows
    # FIXME: Temporarily disabled due to upstream nixpkgs issue where
    # sphinx 9.1.0 doesn't support Python 3.11 (wsdd dependency chain)
    # services.samba-wsdd = {
    #   enable = true;
    #   openFirewall = true;
    # };

    # Enable Avahi for service discovery
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish.enable = true;
      publish.userServices = true;
      # Without addresses=true Avahi advertises the _adisk._tcp service but never
      # publishes the host A record, so macOS resolves "<host>.local" to nothing
      # and the Time Machine connection fails.
      publish.addresses = true;
      publish.workstation = true;
      extraServiceFiles = {
        smb = ''
          <?xml version="1.0" standalone='no'?>
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
            <name replace-wildcards="yes">%h SMB</name>
            <service>
              <type>_smb._tcp</type>
              <port>445</port>
            </service>
          </service-group>
        '';
        timemachine = ''
          <?xml version="1.0" standalone='no'?>
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
            <name replace-wildcards="yes">%h Time Machine</name>
            <service>
              <type>_adisk._tcp</type>
              <port>9</port>
              <txt-record>sys=waMa=0,adVF=0x100</txt-record>
              <txt-record>dk0=adVN=timemachine,adVF=0x82</txt-record>
            </service>
          </service-group>
        '';
      };
    };

    # Ensure ZFS datasets exist before creating directories
    systemd.services.create-backup-datasets = {
      description = "Create ZFS datasets for backup shares";
      wantedBy = [ "multi-user.target" ];
      before = [ "samba-smbd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script =
        let
          poolName = builtins.head (lib.splitString "/" cfg.backupsRoot);
        in
        ''
          # Check if ZFS pool exists
          if ! ${pkgs.zfs}/bin/zfs list ${poolName} > /dev/null 2>&1; then
            echo "Error: ZFS pool '${poolName}' not found"
            exit 1
          fi

          # Create backup datasets if they don't exist
          for dataset in ${cfg.backupsRoot} ${cfg.backupsRoot}/timemachine ${cfg.backupsRoot}/windows; do
            if ! ${pkgs.zfs}/bin/zfs list "$dataset" > /dev/null 2>&1; then
              echo "Creating ZFS dataset: $dataset"
              ${pkgs.zfs}/bin/zfs create -p "$dataset"
            fi
          done

          # Set dataset properties
          ${pkgs.zfs}/bin/zfs set compression=lz4 ${cfg.backupsRoot}/timemachine
          ${pkgs.zfs}/bin/zfs set compression=lz4 ${cfg.backupsRoot}/windows
          ${pkgs.zfs}/bin/zfs set quota=${cfg.timeMachineQuota} ${cfg.backupsRoot}/timemachine
          ${pkgs.zfs}/bin/zfs set quota=${cfg.windowsBackupQuota} ${cfg.backupsRoot}/windows
        '';
    };

    # Create backup user and group for Windows backups
    users.groups.backup = { };
    users.users.backup = {
      isSystemUser = true;
      group = "backup";
      home = "/${cfg.backupsRoot}";
      createHome = false;
    };

    # Create timemachine user and group for Time Machine backups
    users.groups.timemachine = { };
    users.users.timemachine = {
      isSystemUser = true;
      group = "timemachine";
      home = "/${cfg.backupsRoot}/timemachine";
      createHome = false;
    };

    # Ensure backup directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d /${cfg.backupsRoot} 0755 backup backup -"
      "d /${cfg.backupsRoot}/timemachine 0700 timemachine timemachine -"
      "d /${cfg.backupsRoot}/windows 0755 backup backup -"
    ];

    # Agenix secret for Time Machine password
    age.secrets.samba-timemachine-password = {
      file = cfg.timeMachinePasswordFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Set up Samba timemachine user with password from agenix secret
    systemd.services.samba-timemachine-user = {
      description = "Set up Samba timemachine user";
      wantedBy = [ "multi-user.target" ];
      before = [ "samba-smbd.service" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Read password from agenix secret (strip any trailing newline)
        TIMEMACHINE_PASSWORD=$(tr -d '\n' < ${config.age.secrets.samba-timemachine-password.path})

        # Create or update the timemachine samba user
        echo "Setting up Samba timemachine user..."
        (echo "$TIMEMACHINE_PASSWORD"; echo "$TIMEMACHINE_PASSWORD") | ${pkgs.samba}/bin/smbpasswd -a -s timemachine

        echo "Samba timemachine user configured"
        echo "Time Machine share: smb://$(hostname)/timemachine (user: timemachine)"
      '';
    };
  };
}
