# ks-vega — vega's MCP server, exposed to every coding agent (claude,
# gemini, codex, opencode) via `keystone.terminal.cliCodingAgents`.
#
# Vega is deployed as an OCI image (`git.ncrmro.com/ncrmro/vega:latest`), so
# the local MCP command is a tiny Podman wrapper that starts the same image with
# the `ks-vega` command and proxies stdio JSON-RPC to the dashboard HTTP API at
# $KS_VEGA_SERVER_URL.
#
# Default URL is the tailnet-only nginx vhost on ocean
# (`https://vega.ncrmro.com`), reachable from every host on the headscale
# tailnet. Agent identity comes from $KS_VEGA_AGENT / $KS_AGENT / $USER —
# OS agents inherit `agent-<name>` as $USER from their systemd unit, so no
# extra env wiring is needed for them.
{
  lib,
  pkgs,
  ...
}:
let
  vegaImage = "git.ncrmro.com/ncrmro/vega:latest";
  ksVegaMcpContainer = pkgs.writeShellScript "ks-vega-mcp-container" ''
    set -euo pipefail
    exec ${pkgs.podman}/bin/podman run --rm -i --pull=missing --network=host \
      -e KS_VEGA_SERVER_URL="''${KS_VEGA_SERVER_URL:-https://vega.ncrmro.com}" \
      -e KS_VEGA_HOST="''${KS_VEGA_HOST:-''${HOSTNAME:-}}" \
      -e KS_VEGA_AGENT="''${KS_VEGA_AGENT:-}" \
      -e KS_AGENT="''${KS_AGENT:-}" \
      -e USER="''${USER:-}" \
      ${vegaImage} ks-vega
  '';
in
lib.mkIf pkgs.stdenv.isLinux {
  keystone.terminal.cliCodingAgents.mcpServers.ks-vega = {
    command = toString ksVegaMcpContainer;
    args = [ ];
    env = {
      KS_VEGA_SERVER_URL = "https://vega.ncrmro.com";
    };
  };
}
