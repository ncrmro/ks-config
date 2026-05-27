# Dev sandbox (devbox) — home-manager side.
#
# Spike module. Promotes to keystone/modules/terminal/devbox.nix at refactor.
#
# Exposes the `devbox` CLI and pre-resolves Nix store paths for the tools the
# in-container entrypoint expects (ks, zellij, ttyd, openssh). Pre-resolved
# paths are passed through as env vars so the entrypoint can mount/exec them
# directly instead of running `nix build` at every container start — the same
# pattern keystone.terminal.sandbox uses for podman-agent.
{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  cfg = config.keystone.terminal.devbox;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    optionalAttrs
    ;

  # Inherit defaults from the NixOS-side options when available so per-host
  # tuning stays in one place. Fall back to spike defaults for HM-only invocations.
  osCfg = if osConfig != null then osConfig.keystone.devSandbox or { } else { };
in
{
  options.keystone.terminal.devbox = {
    enable = mkEnableOption "devbox launcher and session vars in this user profile.";

    portBase = mkOption {
      type = types.port;
      default = osCfg.ports.base or 20000;
      description = "Mirror of keystone.devSandbox.ports.base for the user shell.";
    };

    portSpan = mkOption {
      type = types.int;
      default = osCfg.ports.span or 16;
      description = "Mirror of keystone.devSandbox.ports.span for the user shell.";
    };

    reposDir = mkOption {
      type = types.str;
      default = osCfg.reposDir or "${config.home.homeDirectory}/repo";
      description = "Mirror of keystone.devSandbox.reposDir for the user shell.";
    };

    nixVolumeName = mkOption {
      type = types.str;
      default = osCfg.nixVolumeName or "devbox-nix-shared";
      description = "Mirror of keystone.devSandbox.nixVolumeName for the user shell.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.devbox ];

    home.sessionVariables =
      {
        DEVBOX_PORT_BASE = toString cfg.portBase;
        DEVBOX_PORT_SPAN = toString cfg.portSpan;
        DEVBOX_REPOS_DIR = cfg.reposDir;
        DEVBOX_NIX_VOLUME = cfg.nixVolumeName;

        # Pre-resolved store paths the in-container entrypoint mounts. Same
        # mechanism as keystone.terminal.sandbox in podman-agent — saves a
        # `nix build` round-trip on every container start.
        DEVBOX_KS_PATH = "${pkgs.keystone.ks or pkgs.hello}";
        DEVBOX_ZELLIJ_PATH = "${pkgs.zellij}";
        DEVBOX_TTYD_PATH = "${pkgs.ttyd}";
        DEVBOX_OPENSSH_PATH = "${pkgs.openssh}";
        DEVBOX_BASH_PATH = "${pkgs.bashInteractive}";
        DEVBOX_COREUTILS_PATH = "${pkgs.coreutils}";
        DEVBOX_GIT_PATH = "${pkgs.git}";
        DEVBOX_GH_PATH = "${pkgs.gh}";
        DEVBOX_DIRENV_PATH = "${pkgs.direnv}";
      }
      // optionalAttrs (osCfg.adminUser or null != null) {
        DEVBOX_ADMIN_USER = osCfg.adminUser;
      }
      // optionalAttrs (osCfg.github.secrets or { } != { }) {
        # JSON blob the launcher reads to know which agenix files to probe.
        # Format: { "<owner>": { "ownerSecret": "...", "repoSecrets": { ... } } }
        DEVBOX_PAT_SECRETS = builtins.toJSON osCfg.github.secrets;
      };
  };
}
