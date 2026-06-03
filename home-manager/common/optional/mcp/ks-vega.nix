# ks-vega — vega's MCP server, exposed to every coding agent (claude,
# gemini, codex, opencode) via `keystone.terminal.cliCodingAgents`.
#
# The `ks-vega` binary ships out of vega's nix package
# (`inputs.vega.packages.<system>.vega`/bin/ks-vega) and proxies stdio
# JSON-RPC into the dashboard HTTP API at $KS_VEGA_SERVER_URL.
#
# Default URL is the tailnet-only nginx vhost on ocean
# (`https://vega.ncrmro.com`), reachable from every host on the headscale
# tailnet. Agent identity comes from $KS_VEGA_AGENT / $KS_AGENT / $USER —
# OS agents inherit `agent-<name>` as $USER from their systemd unit, so no
# extra env wiring is needed for them.
#
# Linux-only (the vega derivation declares `meta.platforms = linux`); the
# import is a no-op on darwin.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  vegaPkg = inputs.vega.packages.${pkgs.stdenv.hostPlatform.system}.vega or null;
in
lib.mkIf (pkgs.stdenv.isLinux && vegaPkg != null) {
  keystone.terminal.cliCodingAgents.mcpServers.ks-vega = {
    command = "${vegaPkg}/bin/ks-vega";
    args = [ ];
    env = {
      KS_VEGA_SERVER_URL = "https://vega.ncrmro.com";
    };
  };
}
