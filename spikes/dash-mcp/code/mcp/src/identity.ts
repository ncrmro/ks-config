import { hostname as osHostname } from "node:os";

export type Identity = { host: string; agent: string };

export function resolveIdentity(): Identity {
  const host =
    process.env.DASH_MCP_HOST ??
    process.env.HOSTNAME ??
    osHostname() ??
    "unknown-host";
  const agent =
    process.env.DASH_MCP_AGENT ??
    process.env.KS_AGENT ??
    process.env.AGENT_NAME ??
    process.env.USER ??
    "unknown-agent";
  return { host, agent };
}

export function serverUrl(): string {
  return (
    process.env.DASH_MCP_SERVER_URL ??
    `http://127.0.0.1:${process.env.DASH_MCP_PORT ?? "7878"}`
  );
}
