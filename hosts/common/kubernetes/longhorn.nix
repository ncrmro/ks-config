{
  config,
  pkgs,
  lib,
  ...
}:
{
  # iSCSI is required for Longhorn distributed block storage
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };

  # Install iSCSI tools for Longhorn
  environment.systemPackages = [
    pkgs.openiscsi
  ];

  # Make iSCSI tools available for Longhorn CSI driver (following ZFS pattern)
  systemd.services.iscsi-tools = {
    description = "iSCSI tools for Longhorn";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.coreutils}/bin/mkdir -p /usr/bin"
        "${pkgs.coreutils}/bin/ln -sf ${pkgs.openiscsi}/bin/iscsiadm /usr/bin/iscsiadm"
      ];
      RemainAfterExit = true;
    };
    wantedBy = [ "multi-user.target" ];
  };

  # Only deploy Helm charts on K3s server nodes
  services.k3s.autoDeployCharts =
    lib.mkIf (config.services.k3s.enable && config.services.k3s.role == "server")
      {
        # Longhorn Helm Chart: https://artifacthub.io/packages/helm/longhorn/longhorn
        longhorn = {
          name = "longhorn";
          repo = "https://charts.longhorn.io";
          version = "1.8.0";
          hash = "sha256-CV3ZBvYEAtD3Peaqu/knQcPEMod/CQFAWyIonzvX7Uw=";
          targetNamespace = "longhorn-system";
          createNamespace = true;
          values = {
            # Longhorn configuration
            persistence = {
              defaultClass = false; # Don't make Longhorn the default storage class
              defaultClassReplicaCount = 2; # Default replica count for new volumes
            };

            # Ingress configuration for Longhorn UI
            ingress = {
              enabled = true;
              ingressClassName = "nginx";
              host = "longhorn.ncrmro.com";
              tls = true;
              # Using default ingress-nginx wildcard cert (*.ncrmro.com)
              annotations = {
                "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
                "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true";
                # Tailscale/headscale-only, enforced here now that the NixOS
                # nginx front forwards without its own allow/deny block
                "nginx.ingress.kubernetes.io/whitelist-source-range" = "100.64.0.0/10,fd7a:115c:a1e0::/48";
              };
            };

            # Default settings for Longhorn
            defaultSettings = {
              backupstorePollInterval = "300";
              createDefaultDiskLabeledNodes = false;
              defaultDataPath = "/var/lib/longhorn/";
              defaultDataLocality = "disabled";
              replicaSoftAntiAffinity = false;
              storageOverProvisioningPercentage = "100";
              storageMinimalAvailablePercentage = "25";
              upgradeChecker = false;
              defaultReplicaCount = "2";
              # Resource guarantees for stable performance
              guaranteedEngineManagerCPU = "12";
              guaranteedReplicaManagerCPU = "12";
              # Enable concurrent volume rebuilding for better performance
              concurrentVolumeBackupRestorePerNodeLimit = "5";
              # Disable auto-salvage to prevent data corruption
              autoSalvage = false;
              # Set reasonable timeout for node operations
              nodeDownPodDeletionPolicy = "delete-both-statefulset-and-deployment-pod";
            };

            # Resource limits for Longhorn components
            longhornManager = {
              priorityClass = "";
              tolerations = [
                {
                  key = "ncrmro.com/region";
                  operator = "Equal";
                  value = "us-south-2";
                  effect = "NoSchedule";
                }
              ];
              ## Node selector for manager pods
              # nodeSelector = {
              #   "kubernetes.io/hostname" = "ocean";
              # };
            };

            longhornDriver = {
              priorityClass = "";
              tolerations = [
                {
                  key = "ncrmro.com/region";
                  operator = "Equal";
                  value = "us-south-2";
                  effect = "NoSchedule";
                }
              ];
              ## Node selector for driver pods
              # nodeSelector = {
              #   "kubernetes.io/hostname" = "ocean";
              # };
            };

            longhornUI = {
              priorityClass = "";
              tolerations = [
                {
                  key = "ncrmro.com/region";
                  operator = "Equal";
                  value = "us-south-2";
                  effect = "NoSchedule";
                }
              ];
              ## Node selector for UI pods
              # nodeSelector = {
              #   "kubernetes.io/hostname" = "ocean";
              # };
            };
          };
        };
      };

  # Longhorn-based storage classes - only on server nodes
  services.k3s.manifests =
    lib.mkIf (config.services.k3s.enable && config.services.k3s.role == "server")
      {
        # ReadWriteMany storage class using Longhorn with NFS
        "longhorn-rwx-storage-class".content = {
          apiVersion = "storage.k8s.io/v1";
          kind = "StorageClass";
          metadata = {
            name = "longhorn-rwx";
            annotations = {
              "storageclass.kubernetes.io/is-default-class" = "false";
            };
          };
          provisioner = "driver.longhorn.io";
          allowVolumeExpansion = true;
          reclaimPolicy = "Delete";
          volumeBindingMode = "Immediate";
          parameters = {
            numberOfReplicas = "2";
            staleReplicaTimeout = "2880"; # 48 hours
            fromBackup = "";
            fsType = "ext4";
            dataLocality = "disabled";
            # For RWX, Longhorn creates an NFS server pod
            migratable = "false";
            # NFS options for RWX volumes
            nfsOptions = "vers=4.1,proto=tcp,fsc";
          };
          # Allow RWX access modes
          allowedTopologies = [ ];
        };
      };
}
