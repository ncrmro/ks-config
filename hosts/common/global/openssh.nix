# Root SSH access is restricted to hardware keys only via
# keystone.hardwareKey.rootKeys. Normal privileged access uses sudo/wheel.
{ lib, ... }:
{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = lib.mkDefault "prohibit-password";
  };
}
