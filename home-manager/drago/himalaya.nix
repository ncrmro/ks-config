{
  config,
  lib,
  pkgs,
  ...
}:
{
  keystone.terminal.mail = {
    enable = true;
    accountName = "drago";
    email = "drago@ncrmro.com";
    displayName = "Drago";
    login = "drago";
    host = "mail.ncrmro.com";
    passwordCommand = "cat /run/agenix/ncrmro-workstation-agent-drago-mail-password";
  };
}
