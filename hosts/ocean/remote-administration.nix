{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Standalone module from the split OS repo; reuses this fleet's existing
  # privilegedApproval catalog without replacing the fleet's legacy OS input.
  imports = [ "${inputs.keystone-admin}/modules/os/remote-administration.nix" ];
  keystone.security.remoteAdministration = {
    enable = true;
    credentials.macbook = {
      publicKey = null;
      description = "Owner Mac Secure Enclave";
    };
    actions = [
      "ocean-k3s-status"
      "ocean-k3s-restart"
    ];
    durableJobs.ocean-k3s-restart = "keystone-admin-k3s-restart@.service";
  };
  keystone.security.privilegedApproval.commands = lib.mkAfter [
    {
      name = "ocean-k3s-status";
      displayName = "Read K3s status";
      reason = "Inspect Ocean’s Kubernetes service";
      match = "exact";
      argv = [
        "${pkgs.systemd}/bin/systemctl"
        "show"
        "k3s.service"
        "--property=ActiveState,SubState,MainPID,Result"
      ];
    }
    {
      name = "ocean-k3s-restart";
      displayName = "Restart K3s";
      reason = "Restart Ocean’s Kubernetes service";
      match = "exact";
      argv = [
        "${pkgs.systemd}/bin/systemctl"
        "start"
        "--no-block"
        "keystone-admin-k3s-restart@.service"
      ];
    }
  ];
  systemd.services."keystone-admin-k3s-restart@" = {
    description = "Owner-approved K3s restart";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.systemd}/bin/systemctl restart k3s.service";
    };
  };
}
