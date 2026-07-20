{
  pkgs,
  inputs,
  lib,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  testMicrovmTpm = inputs.keystone.packages.${system}.test-microvm-tpm or null;
in
{
  packages = with pkgs; [
    nixfmt-classic
    jq
    yq
  ];

  scripts.k8s-apply = {
    description = "Apply Ocean's K3s HelmCharts and cluster resources";
    exec = ./k8s-cluster/scripts/k8s-apply;
    packages = [
      pkgs.kubectl
      pkgs.yq-go
    ];
  };

  scripts.k8s-apply-secrets = {
    description = "Decrypt and apply Ocean's agenix-managed Kubernetes Secrets";
    exec = ./k8s-cluster/scripts/k8s-apply-secrets;
    packages = [
      inputs.keystone.inputs.agenix.packages.${system}.default
      pkgs.kubectl
      pkgs.yq-go
    ];
  };

  process.manager.implementation = "process-compose";

  processes = lib.optionalAttrs (testMicrovmTpm != null) {
    vm-tpm-microvm = {
      exec = "${testMicrovmTpm}/bin/test-microvm-tpm";
      process-compose = {
        availability.restart = "no";
        readiness_probe.exec.command = "pgrep -f tpm-microvm";
      };
    };
  };
}
