# hosts.nix — Host registry for `ks build` and `ks update`.
#
# This file is the single source of truth for host identity and connection details.
# - NixOS modules: imported via hosts/common/global/default.nix
# - Shell scripts: read via `nix eval -f hosts.nix --json <host>`
#
# Keys MUST match nixosConfigurations names in flake.nix.
# The hostname field MUST match the host's networking.hostName.
#
# sshTarget defaults to "${hostname}.${keystone.headscaleDomain}" when
# headscaleDomain is set. Only override for VPS direct IPs or null for
# local-only hosts.
#
{
  ocean = {
    hostname = "ocean";
    fallbackIP = "192.168.1.10";
    role = "server";
    buildOnRemote = true;
    journalRemote = true;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7Oo3b71YDnN2i3vOsXrE4PFhmByjCIW5YtH7VkrTtC";
    zfs.backups.rpool.targets = [
      "ocean:ocean"
      "maia:lake"
    ];
  };
  mercury = {
    hostname = "mercury";
    sshTarget = "216.128.136.32"; # Vultr VPS, no Tailscale DNS
    role = "server";
    buildOnRemote = false;
    baremetal = false;
  };
  maia = {
    hostname = "maia";
    role = "server";
    buildOnRemote = true;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtdLpd4fI4U4JSQeo0z/m2KdB+qAGyURSPko7/1BCIa";
  };
  ncrmro-workstation = {
    hostname = "ncrmro-workstation";
    tailscaleIP = "100.64.0.3";
    role = "client";
    buildOnRemote = true;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMalqC7xISpPwp7pPHcx8Qc3eiA1LOqJAmflFlHH0oCw";
    zfs.backups.rpool.targets = [
      "ocean:ocean"
      "maia:lake"
    ];
  };
  ncrmro-laptop = {
    hostname = "ncrmro-laptop";
    role = "client";
    buildOnRemote = false;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdFyolB6Fb6z8r+38nsqDig9II1D400COykJPUs2G18";
    zfs.backups.rpool.targets = [ "maia:lake" ];
  };
  catalystPrimary = {
    hostname = "catalyst-primary";
    sshTarget = "144.202.67.5"; # Vultr VPS, no Tailscale DNS
    role = "server";
    buildOnRemote = false;
    baremetal = false;
  };
}
