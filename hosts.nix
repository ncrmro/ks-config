# hosts.nix — Host registry for `ks build` and `ks update`.
#
# This file is the single source of truth for host identity and connection details.
# - NixOS modules: imported via hosts/common/global/default.nix
# - Shell scripts: read via `nix eval -f hosts.nix --json <host>`
#
# Keys MUST match nixosConfigurations names in flake.nix.
# The hostname field MUST match the host's networking.hostName.
#
{
  ocean = {
    hostname = "ocean";
    sshTarget = "ocean.mercury";
    fallbackIP = "192.168.1.10";
    role = "server";
    buildOnRemote = true;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7Oo3b71YDnN2i3vOsXrE4PFhmByjCIW5YtH7VkrTtC";
    zfs.backups.rpool.targets = [
      "ocean:ocean"
      "maia:lake"
    ];
  };
  mercury = {
    hostname = "mercury";
    sshTarget = "216.128.136.32";
    role = "server";
    buildOnRemote = false;
    baremetal = false; # Vultr VPS
  };
  maia = {
    hostname = "maia";
    sshTarget = "maia.mercury";
    role = "server";
    buildOnRemote = true;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtdLpd4fI4U4JSQeo0z/m2KdB+qAGyURSPko7/1BCIa";
  };
  mox = {
    hostname = "mox";
    sshTarget = "mox.mercury";
    role = "client";
    buildOnRemote = true;
  };
  ncrmro-workstation = {
    hostname = "ncrmro-workstation";
    sshTarget = "ncrmro-workstation.mercury";
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
    sshTarget = null;
    role = "client";
    buildOnRemote = false;
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdFyolB6Fb6z8r+38nsqDig9II1D400COykJPUs2G18";
    zfs.backups.rpool.targets = [ "maia:lake" ];
  };
  devbox = {
    hostname = "ncrmro-devbox";
    sshTarget = "ncrmro-devbox.mercury";
    role = "client";
    buildOnRemote = false;
    baremetal = false; # cloud dev instance
  };
  catalystPrimary = {
    hostname = "catalyst-primary";
    sshTarget = "144.202.67.5";
    role = "server";
    buildOnRemote = false;
    baremetal = false; # Vultr VPS
  };
  test-vm = {
    hostname = "test-vm";
    sshTarget = null;
    role = "client";
    buildOnRemote = false;
    baremetal = false; # libvirt VM
  };
  testbox = {
    hostname = "testbox";
    sshTarget = null;
    role = "client";
    buildOnRemote = false;
    baremetal = false; # libvirt VM
  };
  build-vm-desktop = {
    hostname = "build-vm-desktop";
    sshTarget = null;
    role = "client";
    buildOnRemote = false;
    baremetal = false; # libvirt VM
  };
}
