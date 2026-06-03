{ pkgs }:
{
  claude-code = pkgs.callPackage ./claude-code { };
  # codex = pkgs.callPackage ./codex { };
  devbox = pkgs.callPackage ./devbox { };
  gemini-cli = pkgs.callPackage ./gemini-cli { };
  mcp-language-server = pkgs.callPackage ./mcp-language-server { };
  zesh = pkgs.callPackage ./zesh { };
}
