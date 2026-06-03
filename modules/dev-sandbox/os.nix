# Dev sandbox (devbox) — NixOS-side enablement.
#
# Spike module. Promotes to keystone/modules/os/dev-sandbox.nix at refactor time.
#
# Depends on keystone.os.containers.enable (rootless podman + fuse-overlayfs on
# ZFS). PAT secrets are declared by the consumer with owner = adminUser so the
# rootless podman process can read /run/agenix/<name> at launch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.keystone.devSandbox;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.keystone.devSandbox = {
    enable = mkEnableOption "Dev sandbox container fleet (devbox launcher).";

    adminUser = mkOption {
      type = types.str;
      default = "ncrmro";
      description = ''
        Local user that owns devbox containers, reads /run/agenix files, and
        runs systemctl --user. Must match the owner of any
        keystone.devSandbox.github.secrets.* agenix file.
      '';
    };

    reposDir = mkOption {
      type = types.str;
      default = "/home/${cfg.adminUser}/repos";
      description = ''
        Host directory under which OWNER/REPO checkouts live. The launcher
        bind-mounts <reposDir>/<owner>/<repo> into the container at /work.
      '';
    };

    ports = {
      base = mkOption {
        type = types.port;
        default = 20000;
        description = "First port in the devbox port pool.";
      };
      span = mkOption {
        type = types.ints.between 4 256;
        default = 16;
        description = ''
          Ports reserved per devbox instance. The first two are WEB (ttyd) and
          SSH (sshd); the remainder are available to user processes inside the
          container via $DEV_PORTS.
        '';
      };
      maxInstances = mkOption {
        type = types.int;
        default = 32;
        description = "Hard cap on concurrent devbox instances.";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open the full port range on the host firewall. Off by default —
        leave the sandbox LAN-only or expose explicitly per-host.
      '';
    };

    nixVolumeName = mkOption {
      type = types.str;
      default = "devbox-nix-shared";
      description = ''
        Podman named volume backing /nix inside the container. Shared across
        all devbox instances by default — the dedup wins of a single store
        dominate the isolation costs.
      '';
    };

    github.secrets = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              ownerSecret = mkOption {
                type = types.str;
                example = "ncrmro-github-pat-ncrmro";
                description = ''
                  agenix secret name (without .age) covering all repos owned by
                  this GitHub owner. Mounted to /run/agenix/<ownerSecret>.
                '';
              };
              repoSecrets = mkOption {
                type = types.attrsOf types.str;
                default = { };
                example = {
                  "private-repo" = "ncrmro-github-pat-ncrmro-private-repo";
                };
                description = ''
                  Optional per-repo override secrets (REPO → agenix name).
                  Resolved before the owner-wide secret at launch.
                '';
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Per-GitHub-owner PAT bindings. The launcher resolves repo-specific
        first, then owner-wide. Agenix files MUST be `owner = adminUser`.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (config.keystone.os.containers.enable or false);
        message = ''
          keystone.devSandbox.enable requires keystone.os.containers.enable
          (rootless podman with fuse-overlayfs — required for ZFS hosts).
        '';
      }
      {
        assertion = cfg.ports.base + cfg.ports.span * cfg.ports.maxInstances <= 65535;
        message = ''
          keystone.devSandbox port pool (base=${toString cfg.ports.base},
          span=${toString cfg.ports.span},
          maxInstances=${toString cfg.ports.maxInstances}) exceeds 65535.
        '';
      }
    ];

    # Lingering lets the user's systemd instance run after logout so Quadlet
    # `.container` units survive reboot without an active shell session.
    users.users.${cfg.adminUser}.linger = true;

    networking.firewall.allowedTCPPortRanges = mkIf cfg.openFirewall [
      {
        from = cfg.ports.base;
        to = cfg.ports.base + cfg.ports.span * cfg.ports.maxInstances - 1;
      }
    ];

    # Make the launcher discoverable system-wide. The home-manager module also
    # installs it into the admin user's profile, but exposing here means
    # service scripts and other users on the host can find it too.
    environment.systemPackages = [ pkgs.devbox ];

    # Surface the host-level configuration to the launcher (which runs as the
    # admin user) via environment variables read at launch time. Home-manager
    # session vars cover interactive shells; this covers the case where the
    # launcher is invoked from a non-shell context (cron, systemd user unit).
    environment.variables = {
      DEVBOX_PORT_BASE = toString cfg.ports.base;
      DEVBOX_PORT_SPAN = toString cfg.ports.span;
      DEVBOX_MAX_INSTANCES = toString cfg.ports.maxInstances;
      DEVBOX_REPOS_DIR = cfg.reposDir;
      DEVBOX_NIX_VOLUME = cfg.nixVolumeName;
      DEVBOX_IMAGE = "localhost/devbox-${cfg.adminUser}:latest";
    };
  };
}
