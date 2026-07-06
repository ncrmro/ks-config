# Forgejo Actions runner overrides for ocean.
#
# Keystone's git-server module (milestone/M10-V2-os-agents) provides the
# runner with rootless podman; this module layers ks-config-local fixes on
# top without touching keystone:
#   - registration URL reachable from inside job containers
#   - node:22 label mapping (pi requires Node >= 22.19)
#   - concurrency (capacity) and per-job container resource limits
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # CRITICAL: keystone renders its own config file into the ExecStart wrapper,
  # so services.gitea-actions-runner.instances.*.settings is ignored. This
  # wrapper replicates keystone's env setup and swaps in our config.
  runnerConfig = (pkgs.formats.yaml { }).generate "forgejo-runner-ocean-config.yaml" {
    runner = {
      file = ".runner";
      # Concurrent jobs. Ocean has 16 cores but ZFS ARC keeps memory tight;
      # 3 jobs x 2G stays well inside what the host can spare.
      capacity = 3;
    };
    container = {
      # Per-job container limits, passed to podman create.
      options = "--memory=2g --memory-swap=2g --cpus=4";
    };
  };
  runnerWrapper = pkgs.writeShellScript "forgejo-runner-daemon-ocean-ks" ''
    set -euo pipefail
    uid="$(${pkgs.coreutils}/bin/id -u gitea-runner)"
    export XDG_RUNTIME_DIR="/run/user/$uid"
    export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
    exec ${config.services.gitea-actions-runner.package}/bin/act_runner daemon --config ${runnerConfig}
  '';
in
{
  # CRITICAL: the runner must register with a URL reachable from inside job
  # containers. Keystone defaults to http://127.0.0.1:3001, which becomes
  # GITHUB_SERVER_URL/GITHUB_API_URL in jobs — inside a container 127.0.0.1 is
  # the container itself, so actions/checkout and all API calls fail.
  services.gitea-actions-runner.instances.ocean.url = lib.mkForce "https://git.ncrmro.com";

  # node:22 for docker-label jobs: pi (outfitter's agent) requires Node >= 22.19,
  # and keystone's default maps ubuntu-latest to node:20.
  services.gitea-actions-runner.instances.ocean.labels = lib.mkForce [
    "native:host"
    "ubuntu-latest:docker://node:22-bookworm"
    "ubuntu-24.04:docker://node:22-bookworm"
    "ubuntu-22.04:docker://node:20-bookworm"
  ];

  systemd.services."gitea-runner-ocean".serviceConfig = {
    # Keystone mkForces its own wrapper (priority 50); mkOverride 40 wins.
    ExecStart = lib.mkOverride 40 runnerWrapper;
    # Caps the runner daemon itself; job containers are capped separately via
    # container.options above (they run under the gitea-runner user manager,
    # not this service's cgroup).
    MemoryMax = "1G";
    CPUQuota = "200%";
  };
}
