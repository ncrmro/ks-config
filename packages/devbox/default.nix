{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  podman,
  systemd,
  coreutils,
}:
stdenvNoCC.mkDerivation {
  pname = "devbox";
  version = "0.1.0-spike";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/devbox
    install -m 0644 $src/entrypoint.sh $out/share/devbox/entrypoint.sh
    install -m 0755 $src/devbox.py $out/share/devbox/devbox.py

    # Wrap with python3 + ensure `podman` and `systemctl` are on PATH at runtime.
    makeWrapper ${python3}/bin/python3 $out/bin/devbox \
      --add-flags "$out/share/devbox/devbox.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          podman
          systemd
          coreutils
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "Long-lived per-repo dev sandbox launcher (Quadlet + podman)";
    mainProgram = "devbox";
    platforms = lib.platforms.linux;
  };
}
