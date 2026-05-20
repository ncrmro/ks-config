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
set -eu

# -- nix config -------------------------------------------------------------
mkdir -p /etc/nix
cat > /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
sandbox = false
EOF

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
  _resolved=$(nix build --no-link --print-out-paths "$_flake")
  export PATH="$_resolved/bin:$PATH"
}

resolve_tool ks       DEVBOX_KS_PATH        nixpkgs#hello   # ks is keystone-only; hello is a no-op fallback
resolve_tool zellij   DEVBOX_ZELLIJ_PATH    nixpkgs#zellij
resolve_tool ttyd     DEVBOX_TTYD_PATH      nixpkgs#ttyd
resolve_tool sshd     DEVBOX_OPENSSH_PATH   nixpkgs#openssh
resolve_tool bash     DEVBOX_BASH_PATH      nixpkgs#bashInteractive
resolve_tool git      DEVBOX_GIT_PATH       nixpkgs#git
resolve_tool gh       DEVBOX_GH_PATH        nixpkgs#gh
resolve_tool direnv   DEVBOX_DIRENV_PATH    nixpkgs#direnv

# Add coreutils last so its 'env'/'cat' etc. don't shadow the nixos/nix image's busybox.
if [ -n "${DEVBOX_COREUTILS_PATH:-}" ]; then
  export PATH="$PATH:$DEVBOX_COREUTILS_PATH/bin"
fi

# -- ssh host keys ----------------------------------------------------------
# /etc/ssh is a named volume → host keys persist across restarts.
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -A
fi

mkdir -p /root/.ssh
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

# Pre-create the session for the repo so ttyd has something to attach to
# even before a user opens a shell.
SESSION="${DEVBOX_REPO:-devbox}"
if ! zellij list-sessions 2>/dev/null | grep -q "^${SESSION}\b"; then
  # `zellij setup --check` doesn't create; instead spawn a detached session
  # by feeding /dev/null to a short-lived zellij invocation.
  ( cd /work && zellij --session "$SESSION" attach --create-background ) >/dev/null 2>&1 || true
fi

# -- ssh + ttyd -------------------------------------------------------------
# sshd binds 22 (container port). The Quadlet PublishPort lines map host
# DEV_PORT_SSH → 22. ttyd binds 7681 → DEV_PORT_WEB.
sshd -D &
SSHD_PID=$!

# ttyd fronts `zellij attach -c $SESSION`. -W enables writeable mode; -W is
# default in modern ttyd but pass explicitly. No auth on ttyd itself for the
# spike — exposure is gated by the host port being LAN-only by default.
ttyd -p 7681 \
  -t fontSize=14 \
  -t 'theme={"background":"#1d1f21"}' \
  /bin/sh -lc "cd /work && zellij attach -c '$SESSION'" &
TTYD_PID=$!

trap 'kill $SSHD_PID $TTYD_PID 2>/dev/null || true; exit 0' TERM INT

# Keep the container alive. Wait on whichever child dies first so systemd
# notices and triggers Restart=always.
wait -n $SSHD_PID $TTYD_PID
