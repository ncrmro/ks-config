{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  testMicrovmTpm = inputs.keystone.packages.${system}.test-microvm-tpm;
in
{
  packages = with pkgs; [ nixfmt-classic jq yq ];

  process.manager.implementation = "process-compose";

  processes.vm-tpm-microvm = {
    exec = "${testMicrovmTpm}/bin/test-microvm-tpm";
    process-compose = {
      availability.restart = "no";
      readiness_probe.exec.command = "pgrep -f tpm-microvm";
    };
  };
}
