{
  pkgs,
  ...
}:
{
  # Eternal Terminal - persistent remote shell client
  # https://eternalterminal.dev/
  home.packages = with pkgs; [
    eternal-terminal
  ];
}
