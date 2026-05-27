#!/usr/bin/env python3
"""devbox — long-lived per-repo dev sandbox launcher.

Renders a Quadlet `.container` unit per <owner>/<repo>, allocates a port range
from a flock-protected JSON state file, resolves a GitHub PAT from agenix via
fallback (repo > owner > default), and brings the container up via
`systemctl --user start devbox-<owner>-<repo>.service`.

No SDK. All container ops are `subprocess.run(["podman", ...])`. Matches the
keystone idiom (podman-agent.sh is bash; this is bash with a state file).
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

NAME_RE = re.compile(r"^[a-zA-Z0-9._-]+$")

# ---- env helpers -----------------------------------------------------------

HOME = Path(os.environ.get("HOME", "/"))
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "devbox"
STATE_FILE = STATE_DIR / "instances.json"
QUADLET_DIR = HOME / ".config" / "containers" / "systemd"
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))

AGENIX_DIR = Path("/run/agenix")
DEFAULT_PAT = AGENIX_DIR / "ncrmro-github-pat-default"

PORT_BASE = int(os.environ.get("DEVBOX_PORT_BASE", "20000"))
PORT_SPAN = int(os.environ.get("DEVBOX_PORT_SPAN", "16"))
MAX_INSTANCES = int(os.environ.get("DEVBOX_MAX_INSTANCES", "32"))
REPOS_DIR = Path(os.environ.get("DEVBOX_REPOS_DIR", HOME / "repos"))
NIX_VOLUME = os.environ.get("DEVBOX_NIX_VOLUME", "devbox-nix-shared")
ADMIN_USER = os.environ.get("DEVBOX_ADMIN_USER") or os.environ.get("USER", "")
PAT_SECRETS = json.loads(os.environ.get("DEVBOX_PAT_SECRETS", "{}"))
DEVBOX_IMAGE = os.environ.get("DEVBOX_IMAGE") or (
    f"localhost/devbox-{ADMIN_USER}:latest" if ADMIN_USER else "localhost/devbox:latest"
)
SEED_MARKER = ".devbox-seeded-image-id"


# ---- types -----------------------------------------------------------------

@dataclass(frozen=True)
class Spec:
    owner: str
    repo: str

    @property
    def slug(self) -> str:
        return f"{self.owner}-{self.repo}"

    @property
    def container_name(self) -> str:
        return f"devbox-{self.slug}"

    @property
    def service_name(self) -> str:
        return f"{self.container_name}.service"

    @property
    def quadlet_path(self) -> Path:
        return QUADLET_DIR / f"{self.container_name}.container"

    @property
    def workdir(self) -> Path:
        # Accept ~/repos/OWNER/REPO. Caller passes OWNER/REPO.
        return REPOS_DIR / self.owner / self.repo


def parse_spec(arg: str) -> Spec:
    if "/" not in arg:
        die(f"expected <owner>/<repo>, got {arg!r}")
    owner, _, repo = arg.partition("/")
    if not (NAME_RE.match(owner) and NAME_RE.match(repo)):
        die(f"<owner>/<repo> must match {NAME_RE.pattern}")
    return Spec(owner=owner, repo=repo)


def die(msg: str, code: int = 1) -> "Never":  # type: ignore[name-defined]
    print(f"devbox: {msg}", file=sys.stderr)
    sys.exit(code)


# ---- state -----------------------------------------------------------------

class State:
    """JSON state file with flock. Maps slug -> {"index": int, "owner": str, "repo": str}."""

    def __init__(self) -> None:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        if not STATE_FILE.exists():
            STATE_FILE.write_text("{}")
        self._fh = STATE_FILE.open("r+")
        fcntl.flock(self._fh.fileno(), fcntl.LOCK_EX)
        self._fh.seek(0)
        self.data = json.load(self._fh)

    def save(self) -> None:
        self._fh.seek(0)
        self._fh.truncate()
        json.dump(self.data, self._fh, indent=2)
        self._fh.flush()

    def close(self) -> None:
        try:
            fcntl.flock(self._fh.fileno(), fcntl.LOCK_UN)
        finally:
            self._fh.close()

    def allocate(self, spec: Spec) -> int:
        if spec.slug in self.data:
            return int(self.data[spec.slug]["index"])
        taken = {int(v["index"]) for v in self.data.values()}
        for i in range(MAX_INSTANCES):
            if i not in taken:
                self.data[spec.slug] = {"index": i, "owner": spec.owner, "repo": spec.repo}
                self.save()
                return i
        die(f"no free port slot — increase keystone.devSandbox.ports.maxInstances (now {MAX_INSTANCES})")

    def forget(self, spec: Spec) -> None:
        self.data.pop(spec.slug, None)
        self.save()


# ---- PAT resolution --------------------------------------------------------

def resolve_pat(spec: Spec) -> Optional[Path]:
    """Repo override > owner-wide > default. Returns the host agenix file or None."""
    owner_cfg = PAT_SECRETS.get(spec.owner) or {}
    repo_secrets = owner_cfg.get("repoSecrets") or {}
    candidates: list[str] = []
    if spec.repo in repo_secrets:
        candidates.append(repo_secrets[spec.repo])
    if owner_cfg.get("ownerSecret"):
        candidates.append(owner_cfg["ownerSecret"])
    candidates.append("ncrmro-github-pat-default")  # fallback name
    for name in candidates:
        p = AGENIX_DIR / name
        if p.is_file():
            return p
    if DEFAULT_PAT.is_file():
        return DEFAULT_PAT
    return None


def ensure_podman_secret(name: str, source: Path) -> None:
    """Idempotently load a host file into a podman secret. Replaces if exists."""
    run(["podman", "secret", "rm", name], check=False, capture_output=True)
    run(["podman", "secret", "create", name, str(source)], check=True)


def inspect_image_id(image: str) -> Optional[str]:
    r = run(["podman", "image", "inspect", image, "--format", "{{.Id}}"], check=False, capture_output=True)
    if r.returncode != 0:
        return None
    return r.stdout.strip() or None


def ensure_nix_volume_seeded(image: str, volume: str) -> None:
    image_id = inspect_image_id(image)
    if not image_id:
        die(
            f"image {image!r} is not loaded in podman — build/load the portable devbox image first"
        )

    run(["podman", "volume", "create", volume], check=False, capture_output=True)
    mountpoint = run(
        ["podman", "volume", "inspect", volume, "--format", "{{.Mountpoint}}"],
        capture_output=True,
    ).stdout.strip()
    if not mountpoint:
        die(f"could not inspect podman volume {volume!r}")

    marker_path = Path(mountpoint) / SEED_MARKER
    if marker_path.is_file() and marker_path.read_text().strip() == image_id:
        return

    run(
        [
            "podman",
            "run",
            "--rm",
            "-v",
            f"{volume}:/mnt/root/nix",
            "--entrypoint",
            "sh",
            image,
            "-lc",
            "nix copy --all --to /mnt/root --no-check-sigs",
        ]
    )
    marker_path.write_text(f"{image_id}\n")


# ---- quadlet rendering -----------------------------------------------------

def render_quadlet(spec: Spec, index: int, pat_secret: Optional[str], image: str) -> str:
    port_offset = PORT_BASE + PORT_SPAN * index
    port_web = port_offset
    port_ssh = port_offset + 1
    # Comma-separated so the value is a single token in systemd's Environment=
    # parser (which splits on whitespace). The entrypoint normalizes commas → spaces.
    extra_ports = ",".join(str(port_offset + i) for i in range(2, PORT_SPAN))

    env_lines: list[str] = [
        f"Environment=DEV_PORT_BASE={port_offset}",
        f"Environment=DEV_PORT_SPAN={PORT_SPAN}",
        f"Environment=DEV_PORT_WEB={port_web}",
        f"Environment=DEV_PORT_SSH={port_ssh}",
        f"Environment=DEV_PORTS={extra_ports}",
        f"Environment=DEVBOX_OWNER={spec.owner}",
        f"Environment=DEVBOX_REPO={spec.repo}",
    ]

    volume_lines = [
        f"Volume={NIX_VOLUME}:/nix",
        f"Volume={spec.workdir}:/work",
        f"Volume=devbox-zellij-{spec.slug}:/var/lib/zellij",
        f"Volume=devbox-ssh-hostkeys-{spec.slug}:/etc/ssh",
        "Volume=devbox-cache-npm:/root/.npm",
        "Volume=devbox-cache-bun:/root/.bun/install/cache",
        "Volume=devbox-cache-pnpm:/root/.local/share/pnpm/store",
        "Volume=devbox-cache-uv:/root/.cache/uv",
        "Volume=devbox-cache-pip:/root/.cache/pip",
        "Volume=devbox-cache-cargo-registry:/usr/local/cargo/registry",
        "Volume=devbox-cache-cargo-git:/usr/local/cargo/git",
        "Volume=devbox-cache-go-build:/root/.cache/go-build",
        "Volume=devbox-cache-go-mod:/go/pkg/mod",
        "Volume=devbox-cache-nix:/root/.cache/nix",
    ]
    # ~/.ssh/authorized_keys for sshd — read-only.
    auth_keys = HOME / ".ssh" / "authorized_keys"
    if auth_keys.is_file():
        volume_lines.append(f"Volume={auth_keys}:/run/authorized_keys:ro")

    # Web + ssh map to the canonical in-container ports for ttyd (7681) and
    # sshd (22). Remaining ports pass through 1:1 so dev processes inside the
    # container bind to whatever DEV_PORTS lists with no port translation.
    publish_lines = [
        f"PublishPort={port_web}:7681",
        f"PublishPort={port_ssh}:22",
    ] + [
        f"PublishPort={port_offset + i}:{port_offset + i}"
        for i in range(2, PORT_SPAN)
    ]

    secret_lines: list[str] = []
    if pat_secret:
        secret_lines.append(f"Secret={pat_secret},type=mount,target=github-pat,mode=0400")

    return "\n".join(
        [
            "# Generated by devbox — do not edit by hand.",
            f"# Spec: {spec.owner}/{spec.repo}  Index: {index}",
            "",
            "[Unit]",
            f"Description=Devbox sandbox for {spec.owner}/{spec.repo}",
            "After=network-online.target",
            "Wants=network-online.target",
            "",
            "[Container]",
            f"ContainerName={spec.container_name}",
            f"Image={image}",
            f"WorkingDir=/work",
            *env_lines,
            *volume_lines,
            *publish_lines,
            *secret_lines,
            "AutoUpdate=registry",
            "Notify=false",
            "",
            "[Service]",
            "Restart=always",
            "RestartSec=5",
            "TimeoutStartSec=300",
            "",
            "[Install]",
            "WantedBy=default.target",
            "",
        ]
    )


# ---- commands --------------------------------------------------------------

def cmd_up(args: argparse.Namespace) -> int:
    spec = parse_spec(args.target)
    if not spec.workdir.exists():
        die(f"{spec.workdir} does not exist — clone the repo there first")
    ensure_nix_volume_seeded(DEVBOX_IMAGE, NIX_VOLUME)

    state = State()
    try:
        index = state.allocate(spec)
    finally:
        state.close()

    pat_file = resolve_pat(spec)
    pat_secret_name: Optional[str] = None
    if pat_file:
        pat_secret_name = f"devbox-pat-{spec.slug}"
        ensure_podman_secret(pat_secret_name, pat_file)
        print(f"devbox: loaded PAT from {pat_file} → podman secret {pat_secret_name}")
    else:
        print("devbox: no GitHub PAT found in /run/agenix — continuing without")

    QUADLET_DIR.mkdir(parents=True, exist_ok=True)
    spec.quadlet_path.write_text(render_quadlet(spec, index, pat_secret_name, DEVBOX_IMAGE))
    print(f"devbox: wrote {spec.quadlet_path}")

    systemctl(["daemon-reload"])
    systemctl(["start", spec.service_name])
    print(f"devbox: started {spec.service_name}")

    port_offset = PORT_BASE + PORT_SPAN * index
    print(f"devbox: web   http://localhost:{port_offset}")
    print(f"devbox: ssh   ssh -p {port_offset + 1} root@localhost")
    print(f"devbox: ports {port_offset}..{port_offset + PORT_SPAN - 1}")
    return 0


def cmd_down(args: argparse.Namespace) -> int:
    spec = parse_spec(args.target)
    systemctl(["stop", spec.service_name], check=False)
    return 0


def cmd_rm(args: argparse.Namespace) -> int:
    spec = parse_spec(args.target)
    systemctl(["stop", spec.service_name], check=False)
    spec.quadlet_path.unlink(missing_ok=True)
    systemctl(["daemon-reload"])
    run(["podman", "secret", "rm", f"devbox-pat-{spec.slug}"], check=False, capture_output=True)
    if not args.keep_volumes:
        for vol in [
            f"devbox-zellij-{spec.slug}",
            f"devbox-ssh-hostkeys-{spec.slug}",
        ]:
            run(["podman", "volume", "rm", vol], check=False, capture_output=True)
    state = State()
    try:
        state.forget(spec)
    finally:
        state.close()
    print(f"devbox: removed {spec.container_name}")
    return 0


def cmd_ls(_args: argparse.Namespace) -> int:
    if not STATE_FILE.exists():
        return 0
    data = json.loads(STATE_FILE.read_text())
    if not data:
        print("(no instances)")
        return 0
    fmt = "{:<32} {:<6} {:<6} {:<6} {:<10}"
    print(fmt.format("SLUG", "INDEX", "WEB", "SSH", "STATUS"))
    for slug, meta in sorted(data.items(), key=lambda kv: kv[1]["index"]):
        idx = int(meta["index"])
        web = PORT_BASE + PORT_SPAN * idx
        ssh_port = web + 1
        status = systemd_active(f"devbox-{slug}.service")
        print(fmt.format(slug, idx, web, ssh_port, status))
    return 0


def cmd_attach(args: argparse.Namespace) -> int:
    spec = parse_spec(args.target)
    os.execvp("podman", [
        "podman", "exec", "-it", spec.container_name,
        "bash", "-lc",
        f"zellij attach -c {spec.repo} || zellij -s {spec.repo}",
    ])


def cmd_web(args: argparse.Namespace) -> int:
    spec = parse_spec(args.target)
    if not STATE_FILE.exists():
        die("no instances")
    data = json.loads(STATE_FILE.read_text())
    if spec.slug not in data:
        die(f"no instance for {spec.slug} — run `devbox up {spec.owner}/{spec.repo}`")
    idx = int(data[spec.slug]["index"])
    print(f"http://localhost:{PORT_BASE + PORT_SPAN * idx}")
    return 0


# ---- subprocess helpers ----------------------------------------------------

def run(cmd: list[str], *, check: bool = True, capture_output: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, capture_output=capture_output, text=True)


def systemctl(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess:
    return run(["systemctl", "--user", *args], check=check)


def systemd_active(unit: str) -> str:
    r = run(["systemctl", "--user", "is-active", unit], check=False, capture_output=True)
    return (r.stdout or "").strip() or "unknown"


# ---- argv ------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="devbox", description="long-lived per-repo dev sandbox")
    sub = p.add_subparsers(dest="cmd", required=True)

    up = sub.add_parser("up", help="render Quadlet + systemctl start")
    up.add_argument("target", help="<owner>/<repo>")
    up.set_defaults(func=cmd_up)

    down = sub.add_parser("down", help="systemctl stop (keep volumes + Quadlet)")
    down.add_argument("target", help="<owner>/<repo>")
    down.set_defaults(func=cmd_down)

    rm = sub.add_parser("rm", help="stop, remove Quadlet + per-instance volumes")
    rm.add_argument("target", help="<owner>/<repo>")
    rm.add_argument("--keep-volumes", action="store_true", help="preserve zellij + sshhostkey volumes")
    rm.set_defaults(func=cmd_rm)

    ls = sub.add_parser("ls", help="list known instances")
    ls.set_defaults(func=cmd_ls)

    at = sub.add_parser("attach", help="podman exec into the running container's zellij")
    at.add_argument("target", help="<owner>/<repo>")
    at.set_defaults(func=cmd_attach)

    web = sub.add_parser("web", help="print ttyd URL for an instance")
    web.add_argument("target", help="<owner>/<repo>")
    web.set_defaults(func=cmd_web)
    return p


def main(argv: Optional[list[str]] = None) -> int:
    if shutil.which("podman") is None:
        die("podman not on PATH — enable keystone.os.containers on this host")
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
