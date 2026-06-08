# Vega MCP is centralized at https://vega.ncrmro.com/mcp.
#
# Do not start a local Podman MCP wrapper here. Pi consumes the central
# Streamable HTTP endpoint through pi-mcp-extension, and OS-agent hosts receive
# their per-agent Pi MCP config from hosts/common/optional/vega-agent-rpc.nix so
# the request carries X-Keystone-Agent / X-Keystone-Host identity headers.
{ ... }:
{
}
