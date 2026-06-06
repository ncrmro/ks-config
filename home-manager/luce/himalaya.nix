{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Himalaya email client configuration for Stalwart
  # Requires: luce user created in Stalwart admin (https://mail.ncrmro.com:8080)
  keystone.terminal.mail = {
    enable = true;
    accountName = "luce";
    email = "luce@ncrmro.com";
    displayName = "Luce";
    login = "luce";
    host = "mail.ncrmro.com";
    passwordCommand = "cat /run/agenix/ocean-agent-luce-mail-password";
  };
}
