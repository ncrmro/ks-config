# Convention-driven ZFS backup module
#
# Reads keystone.hosts topology to auto-derive:
#   - Sender: sanoid snapshots + syncoid replication (local and remote)
#   - Receiver: sync users + ZFS delegation + dataset initialization
#   - Metrics: textfile collector for Prometheus (snapshot age, backup status)
#
# Per-host config is minimal — only poolImportServices.
# SSH authentication uses the host's ed25519 key (/etc/ssh/ssh_host_ed25519_key).
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.my.zfs.backup;
  allHosts = config.keystone.hosts;
  myHostname = config.networking.hostName;

  # Find our key in keystone.hosts by matching hostname
  myHostKey = findFirst (key: allHosts.${key}.hostname == myHostname) null (attrNames allHosts);
  myEntry = if myHostKey != null then allHosts.${myHostKey} else null;

  # Parse "hostKey:pool" target strings
  parseTarget =
    str:
    let
      parts = splitString ":" str;
    in
    {
      hostKey = elemAt parts 0;
      pool = elemAt parts 1;
    };

  # Our outbound backups (we are the source)
  myBackups = if myEntry != null && myEntry.zfs != null then myEntry.zfs.backups else { };

  # Incoming backups (we are a target) — deduplicated by sync user
  incomingBackups = concatLists (
    mapAttrsToList (
      hostKey: hostCfg:
      if hostCfg.zfs != null then
        concatLists (
          mapAttrsToList (
            sourcePool: poolCfg:
            concatMap (
              targetStr:
              let
                t = parseTarget targetStr;
              in
              if t.hostKey == myHostKey then
                [
                  {
                    sourceKey = hostKey;
                    sourceHostname = hostCfg.hostname;
                    sourcePool = sourcePool;
                    targetPool = t.pool;
                  }
                ]
              else
                [ ]
            ) poolCfg.targets
          ) hostCfg.zfs.backups
        )
      else
        [ ]
    ) allHosts
  );

  # Deduplicate sync users (same source host may send multiple pools)
  uniqueSyncUsers = unique (map (i: i.sourceHostname) incomingBackups);

  # Excluded datasets pattern
  excludePattern = "nix$|k3s/server$|k3s/agent$|docker$|containers$|images$|libvirt$";

  # All SSH public keys for a keystone.keys user
  allKeysFor = username: config.keystone.keys.${username}.allKeys;

  # Get authorized keys for a sync user based on source host config
  syncKeysFor =
    hostKey:
    let
      hostCfg = allHosts.${hostKey};
    in
    if hostCfg.hostPublicKey != null then [ hostCfg.hostPublicKey ] else allKeysFor "ncrmro";

  isSender = myBackups != { };
  isReceiver = incomingBackups != [ ];

  # Generate syncoid command name
  syncoidName =
    sourcePool: targetStr:
    let
      t = parseTarget targetStr;
    in
    if t.hostKey == myHostKey then
      "${sourcePool}-local-${t.pool}"
    else
      "${sourcePool}-to-${allHosts.${t.hostKey}.hostname}";

  # Resolve SSH target for a host
  resolveHost =
    hostKey:
    let
      host = allHosts.${hostKey};
    in
    if host.sshTarget != null then host.sshTarget else host.hostname;

  # Unique target pools referenced in incoming backups (for import service deps)
  incomingTargetPools = unique (map (i: i.targetPool) incomingBackups);

  # Import service dependencies for a list of pool names
  importDepsFor =
    pools:
    concatMap (
      pool:
      if hasAttr pool cfg.poolImportServices then [ "${cfg.poolImportServices.${pool}}.service" ] else [ ]
    ) pools;
in
{
  options.my.zfs.backup = {
    poolImportServices = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Map of local pool name to systemd import service for non-boot pools.";
      example = {
        ocean = "import-ocean";
      };
    };
  };

  config = mkMerge [
    # === Sender: sanoid snapshots + syncoid replication ===
    (mkIf isSender {
      environment.systemPackages = [
        pkgs.sanoid
        pkgs.lzop
        pkgs.mbuffer
      ];

      # ZFS maintenance
      services.zfs.trim.enable = mkDefault true;
      services.zfs.autoScrub.enable = mkDefault true;

      # Sanoid snapshot management — one policy per source pool
      services.sanoid.enable = true;
      services.sanoid.datasets = mapAttrs (_pool: _: {
        recursive = true;
        processChildrenOnly = true;
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 0;
        autosnap = true;
        autoprune = true;
      }) myBackups;

      # Syncoid replication — one command per (pool, target) pair
      services.syncoid.enable = true;
      services.syncoid.interval = "hourly";
      services.syncoid.commands = listToAttrs (
        concatLists (
          mapAttrsToList (
            sourcePool: poolCfg:
            map (
              targetStr:
              let
                t = parseTarget targetStr;
                isLocal = t.hostKey == myHostKey;
                targetDataset = "${t.pool}/backups/${myHostname}/${sourcePool}";
                syncUser = "${myHostname}-sync";
                targetHost = resolveHost t.hostKey;
                name = syncoidName sourcePool targetStr;
              in
              nameValuePair name (
                {
                  source = sourcePool;
                  target = if isLocal then targetDataset else "${syncUser}@${targetHost}:${targetDataset}";
                  recursive = true;
                  sendOptions = "w"; # raw send preserves encryption
                  extraArgs = [
                    "--no-sync-snap"
                    "--skip-parent"
                    "--include-snaps=autosnap"
                    "--compress=none"
                    "--exclude-datasets=${excludePattern}"
                  ]
                  ++ (
                    if isLocal then
                      [ "--identifier=${myHostname}-local-backup" ]
                    else
                      [
                        "--identifier=${myHostname}-offsite-${allHosts.${t.hostKey}.hostname}"
                        "--no-privilege-elevation"
                      ]
                  );
                }
                // (
                  if !isLocal then { sshKey = "/run/syncoid/${syncoidName sourcePool targetStr}/ssh_key"; } else { }
                )
              )
            ) poolCfg.targets
          ) myBackups
        )
      );
    })

    # === Sender: SSH key access for remote syncoid commands ===
    # The NixOS syncoid module sandboxes the service as User=syncoid, but
    # the host SSH key at /etc/ssh/ssh_host_ed25519_key is root:root 0600.
    # Use ExecStartPre=+ (root) to copy the key to a syncoid-readable path,
    # then override --sshkey to point there.
    (mkIf isSender {
      systemd.services = listToAttrs (
        concatLists (
          mapAttrsToList (
            sourcePool: poolCfg:
            concatMap (
              targetStr:
              let
                t = parseTarget targetStr;
                isLocal = t.hostKey == myHostKey;
                name = syncoidName sourcePool targetStr;
                serviceName = "syncoid-${name}";
                keyPath = "/run/syncoid/${name}/ssh_key";
                copyKeyScript = pkgs.writeShellScript "syncoid-copy-key-${name}" ''
                  mkdir -p /run/syncoid/${name}
                  cp /etc/ssh/ssh_host_ed25519_key ${keyPath}
                  chown syncoid:syncoid ${keyPath}
                  chmod 0400 ${keyPath}
                '';
              in
              if !isLocal then
                [
                  (nameValuePair serviceName {
                    serviceConfig.ExecStartPre = [ "+${copyKeyScript}" ];
                    # SECURITY: The NixOS syncoid module's default sandboxing adds
                    # InaccessiblePaths for the RuntimeDirectory, which blocks access
                    # to the SSH key we copy there via ExecStartPre. ReadWritePaths
                    # overrides this for the key directory specifically.
                    serviceConfig.ReadWritePaths = [ "/run/syncoid/${name}" ];
                  })
                ]
              else
                [ ]
            ) poolCfg.targets
          ) myBackups
        )
      );
    })

    # === Sender: pool import service dependencies for local targets ===
    (mkIf (isSender && cfg.poolImportServices != { }) {
      systemd.services = listToAttrs (
        concatLists (
          mapAttrsToList (
            sourcePool: poolCfg:
            concatMap (
              targetStr:
              let
                t = parseTarget targetStr;
                isLocal = t.hostKey == myHostKey;
                name = syncoidName sourcePool targetStr;
                serviceName = "syncoid-${name}";
              in
              if isLocal && hasAttr t.pool cfg.poolImportServices then
                [
                  (nameValuePair serviceName {
                    after = [ "${cfg.poolImportServices.${t.pool}}.service" ];
                    requires = [ "${cfg.poolImportServices.${t.pool}}.service" ];
                  })
                ]
              else
                [ ]
            ) poolCfg.targets
          ) myBackups
        )
      );
    })

    # === Receiver: sync users + ZFS delegation ===
    (mkIf isReceiver {
      environment.systemPackages = with pkgs; [
        lzop
        mbuffer
      ];

      users.groups.zfs-sync = { };

      users.users = listToAttrs (
        map (
          syncHostname:
          let
            # Find the host key for this hostname
            hostKey = findFirst (key: allHosts.${key}.hostname == syncHostname) null (attrNames allHosts);
            syncUser = "${syncHostname}-sync";
          in
          nameValuePair syncUser {
            isSystemUser = true;
            shell = pkgs.bash;
            group = "zfs-sync";
            openssh.authorizedKeys.keys = if hostKey != null then syncKeysFor hostKey else [ ];
          }
        ) uniqueSyncUsers
      );

      # Initialize backup datasets and ZFS delegations
      systemd.services.zfs-backup-init = {
        description = "Initialize ZFS backup datasets and delegations";
        wantedBy = [ "multi-user.target" ];
        after = [ "zfs.target" ] ++ importDepsFor incomingTargetPools;
        requires = importDepsFor incomingTargetPools;
        path = [ config.boot.zfs.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = concatStringsSep "\n" (
          map (
            incoming:
            let
              dataset = "${incoming.targetPool}/backups/${incoming.sourceHostname}/${incoming.sourcePool}";
              syncUser = "${incoming.sourceHostname}-sync";
            in
            ''
              # ${syncUser} → ${dataset}
              if ! zfs list ${dataset} >/dev/null 2>&1; then
                zfs create -p ${dataset} || true
              fi
              zfs allow ${syncUser} receive,create,mount,rollback,destroy ${dataset}
            ''
          ) incomingBackups
        );
      };
    })

    # === Metrics: syncoid job status via ExecStopPost ===
    (mkIf isSender {
      systemd.services = listToAttrs (
        concatLists (
          mapAttrsToList (
            sourcePool: poolCfg:
            map (
              targetStr:
              let
                t = parseTarget targetStr;
                name = syncoidName sourcePool targetStr;
                serviceName = "syncoid-${name}";
                targetHostname = allHosts.${t.hostKey}.hostname;
                metricsScript = pkgs.writeShellScript "syncoid-metrics-${name}" ''
                  METRICS_DIR="/var/lib/prometheus-node-exporter"
                  METRICS_FILE="$METRICS_DIR/zfs_backup_${name}.prom"
                  mkdir -p "$METRICS_DIR"

                  EXIT_CODE="''${EXIT_STATUS:-0}"
                  TIMESTAMP=$(date +%s)

                  {
                    echo "# HELP zfs_backup_last_success_timestamp Unix timestamp of last successful backup"
                    echo "# TYPE zfs_backup_last_success_timestamp gauge"
                    echo "# HELP zfs_backup_last_exit_code Exit code of last backup run"
                    echo "# TYPE zfs_backup_last_exit_code gauge"

                    if [ "$EXIT_CODE" = "0" ]; then
                      echo "zfs_backup_last_success_timestamp{job=\"${name}\",source_host=\"${myHostname}\",source_pool=\"${sourcePool}\",target_host=\"${targetHostname}\",target_pool=\"${t.pool}\"} $TIMESTAMP"
                    fi
                    echo "zfs_backup_last_exit_code{job=\"${name}\",source_host=\"${myHostname}\",source_pool=\"${sourcePool}\",target_host=\"${targetHostname}\",target_pool=\"${t.pool}\"} $EXIT_CODE"
                  } > "$METRICS_FILE"
                '';
              in
              nameValuePair serviceName {
                serviceConfig.ExecStopPost = [ "+${metricsScript}" ];
              }
            ) poolCfg.targets
          ) myBackups
        )
      );
    })

    # NOTE: zfs-snapshot-metrics service and timer are now owned by keystone's
    # modules/os/zfs-backup.nix (introduced in PR #214). Declaring them here
    # caused a systemd unit collision during evaluation. Legacy gaps tracked
    # in a follow-up keystone issue; once closed this whole file can be
    # removed in favor of the keystone module.
  ];
}
