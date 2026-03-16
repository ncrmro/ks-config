# TODO: Import keystone modules and migrate to keystone.keys for root authorized_keys.
# This host doesn't use keystone yet — keys are hardcoded as a stopgap.
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./k3s.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "catalyst-primary";
  networking.domain = "";
  networking.hosts = {
    "127.0.0.1" = [
      "primary.catalyst.ncrmro.com"
      "cr.primary.catalyst.ncrmro.com"
    ];
  };
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOyrDBVcGK+pUZOTUA7MLoD5vYK/kaPF6TNNyoDmwNl2 ncrmro@ncrmro-laptop-fw7k"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiFUbcDdzBGNgo7GdRvuRvZ9Yf195pIm2jbiM0uJwW0 ncrmro@ncrmro-workstation"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILEOo3uKwbDN1SJemQx8UPVXv0TjKn2VfZSTVFfp3tlcAAAACnNzaDpuY3Jtcm8="
  ];
  system.stateVersion = "25.05";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
