#!/bin/sh
# devbox in-container entrypoint.
#
# Runs inside `nixos/nix:latest`. Resolves ks/zellij/ttyd/openssh from
# pre-resolved store paths (DEVBOX_*_PATH env), falling back to `nix profile
# install` into the shared /nix volume on first run. Starts sshd and ttyd,
# then keeps the container alive. Users attach via:
#   - web:   http://host:$DEV_PORT_WEB
#   - ssh:   ssh -p $DEV_PORT_SSH root@host
#   - exec:  devbox attach <owner>/<repo>    (from the host)
# Intentionally not `set -e`: one failing nix build (e.g. transient network
# error) shouldn't kill the container — we still want sshd + ttyd up so the
# user can investigate. Individual sections handle their own errors.
set -u

# Normalize commas → spaces in DEV_PORTS (Quadlet Environment= treats spaces
# as separators, so the launcher emits the list comma-separated).
if [ -n "${DEV_PORTS:-}" ]; then
  DEV_PORTS=$(printf '%s' "$DEV_PORTS" | tr ',' ' ')
  export DEV_PORTS
fi

# -- nix config -------------------------------------------------------------
mkdir -p /etc/nix
cat > /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
sandbox = false
EOF

# GitHub token for flake fetcher — authenticated requests get a 5000/hr rate
# limit instead of the unauthenticated 60/hr. DEVBOX_HOST_GH_TOKEN is set by
# the launcher from the host's gh auth state.
if [ -n "${DEVBOX_HOST_GH_TOKEN:-}" ]; then
  echo "access-tokens = github.com=${DEVBOX_HOST_GH_TOKEN}" >> /etc/nix/nix.conf
  export GITHUB_TOKEN="$DEVBOX_HOST_GH_TOKEN"
  export GH_TOKEN="$DEVBOX_HOST_GH_TOKEN"
fi

# -- tool resolution --------------------------------------------------------
# Use pre-resolved store paths when set (avoid network round-trip on every
# start). Fall back to `nix profile install` so the launcher works even
# without the home-manager session vars (e.g. first boot, broken HM).
resolve_tool() {
  _tool="$1"; _var="$2"; _flake="$3"
  _path=$(eval "echo \${$_var:-}")
  if [ -n "$_path" ] && [ -d "$_path/bin" ]; then
    export PATH="$_path/bin:$PATH"
    return 0
  fi
  if command -v "$_tool" >/dev/null 2>&1; then
    return 0
  fi
  if _resolved=$(nix build --no-link --print-out-paths "$_flake" 2>&1); then
    export PATH="$_resolved/bin:$PATH"
  else
    echo "devbox: WARN: could not resolve $_tool ($_flake): $_resolved" >&2
    return 1
  fi
}

resolve_tool ks       DEVBOX_KS_PATH        nixpkgs#hello   || true   # ks is keystone-only; hello is a no-op fallback
resolve_tool zellij   DEVBOX_ZELLIJ_PATH    nixpkgs#zellij  || true
resolve_tool ttyd     DEVBOX_TTYD_PATH      nixpkgs#ttyd    || true
resolve_tool sshd     DEVBOX_OPENSSH_PATH   nixpkgs#openssh || true
resolve_tool bash     DEVBOX_BASH_PATH      nixpkgs#bashInteractive || true
resolve_tool git      DEVBOX_GIT_PATH       nixpkgs#git     || true
resolve_tool gh       DEVBOX_GH_PATH        nixpkgs#gh      || true
resolve_tool direnv   DEVBOX_DIRENV_PATH    nixpkgs#direnv  || true

# Add coreutils last so its 'env'/'cat' etc. don't shadow the nixos/nix image's busybox.
if [ -n "${DEVBOX_COREUTILS_PATH:-}" ]; then
  export PATH="$PATH:$DEVBOX_COREUTILS_PATH/bin"
fi

# -- /etc/passwd + /etc/group ------------------------------------------------
# In nixos/nix:latest, /etc/passwd and /etc/group are symlinks into the
# image's /nix/store. When we bind-mount the host's /nix/store over the
# image's one, those symlink targets disappear → reads/writes via the
# symlink fail with ENOENT. Unlink first, then create as real regular files.
# This also fixes "No user exists for uid 0" which blocks ssh-keygen -A.
rm -f /etc/passwd /etc/group
cat > /etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/var/empty:/bin/false
sshd:x:74:74:sshd:/var/empty:/bin/false
EOF
cat > /etc/group <<'EOF'
root:x:0:
nogroup:x:65534:
sshd:x:74:
EOF
mkdir -p /root /var/empty
chmod 700 /root

# -- ssh host keys ----------------------------------------------------------
# /etc/ssh is a named volume → host keys persist across restarts. ssh-keygen
# can fail if /etc/ssh isn't writable or moduli files are missing — capture
# output so we see what happened.
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  echo "devbox: generating ssh host keys"
  if ! ssh-keygen -A 2>&1; then
    echo "devbox: WARN: ssh-keygen -A failed; ssh will not work" >&2
  fi
fi

mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ -f /run/authorized_keys ]; then
  cp /run/authorized_keys /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# Minimal sshd config — root login only, key auth only, single-instance.
cat > /etc/ssh/sshd_config <<'EOF'
Port 22
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
Subsystem sftp /usr/lib/ssh/sftp-server
AcceptEnv DEV_PORT_* DEVBOX_* GITHUB_TOKEN
PrintMotd no
EOF

# -- github PAT -------------------------------------------------------------
# Surface the PAT to interactive shells (sshd, ttyd → zellij). Mounted as a
# podman secret at /run/secrets/github-pat (mode 0400).
PROFILE_D=/etc/profile.d
mkdir -p "$PROFILE_D"
cat > "$PROFILE_D/devbox-github.sh" <<'EOF'
if [ -f /run/secrets/github-pat ]; then
  GITHUB_TOKEN="$(tr -d '\n' < /run/secrets/github-pat)"
  export GITHUB_TOKEN
  export GH_TOKEN="$GITHUB_TOKEN"
  export GITHUB_TOKEN_FILE=/run/secrets/github-pat
fi
EOF

# Also propagate the port range envs into shells.
cat > "$PROFILE_D/devbox-ports.sh" <<EOF
export DEV_PORT_BASE="${DEV_PORT_BASE:-}"
export DEV_PORT_SPAN="${DEV_PORT_SPAN:-}"
export DEV_PORT_WEB="${DEV_PORT_WEB:-}"
export DEV_PORT_SSH="${DEV_PORT_SSH:-}"
export DEV_PORTS="${DEV_PORTS:-}"
export DEVBOX_OWNER="${DEVBOX_OWNER:-}"
export DEVBOX_REPO="${DEVBOX_REPO:-}"
EOF

# -- zellij session ---------------------------------------------------------
# State dir is a named volume; zellij sessions survive container recreation.
export ZELLIJ_DATA_DIR=/var/lib/zellij
mkdir -p "$ZELLIJ_DATA_DIR"

# Session name for ttyd to attach to. Created lazily by `zellij attach -c`
# on first connection — no pre-create needed (zellij has no detached-create
# mode without a tty).
SESSION="${DEVBOX_REPO:-devbox}"

# -- ssh + ttyd -------------------------------------------------------------
# sshd binds 22 (container port). The Quadlet PublishPort lines map host
# DEV_PORT_SSH → 22. ttyd binds 7681 → DEV_PORT_WEB.
PIDS=""
# sshd refuses to run via $PATH lookup ("requires execution with an absolute
# path") — resolve to its absolute path via `command -v`.
SSHD_BIN=$(command -v sshd 2>/dev/null || true)
TTYD_BIN=$(command -v ttyd 2>/dev/null || true)
ZELLIJ_BIN=$(command -v zellij 2>/dev/null || true)
SHELL_BIN=$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo /bin/sh)

# sshd is best-effort: if it dies (missing host keys, port conflict, anything)
# don't take down the container — ttyd and exec access are the primary entry
# points. We don't add its PID to the wait list.
if [ -n "$SSHD_BIN" ]; then
  "$SSHD_BIN" -D &
  echo "devbox: sshd started (pid $!)"
else
  echo "devbox: WARN: sshd not available — ssh access disabled this run" >&2
fi

TTYD_PID=""
if [ -n "$TTYD_BIN" ] && [ -n "$ZELLIJ_BIN" ]; then
  # ttyd fronts `zellij attach -c $SESSION`. -W makes the terminal writable
  # (required so the user can actually type). No auth on ttyd for the spike —
  # exposure is gated by the host port being LAN-only by default.
  "$TTYD_BIN" -W -p 7681 \
    -t fontSize=14 \
    -t 'theme={"background":"#1d1f21"}' \
    "$SHELL_BIN" -lc "cd /work && '$ZELLIJ_BIN' attach -c '$SESSION'" &
  TTYD_PID=$!
  echo "devbox: ttyd started (pid $TTYD_PID)"
else
  echo "devbox: WARN: ttyd/zellij not available — web access disabled this run" >&2
fi

trap 'echo devbox: shutting down; jobs -p | xargs -r kill 2>/dev/null; exit 0' TERM INT

# The container is alive while ttyd is alive. If ttyd never started, fall
# back to sleep infinity so `podman exec` still works for debugging.
if [ -n "$TTYD_PID" ]; then
  wait "$TTYD_PID"
else
  echo "devbox: no front-end running; sleeping to keep container up for podman exec" >&2
  exec sleep infinity
fi
