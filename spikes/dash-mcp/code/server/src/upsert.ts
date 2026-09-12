import { eq, and, sql } from "drizzle-orm";
import { host, agent } from "@dash-mcp/db/schema";
import type { Db } from "@dash-mcp/db/client";

export async function upsertHostAndAgent(
  db: Db,
  hostname: string,
  agentName: string,
): Promise<{ hostId: number; agentId: number }> {
  const now = sql`(unixepoch())`;

  const [hostRow] = await db
    .insert(host)
    .values({ hostname })
    .onConflictDoUpdate({
      target: host.hostname,
      set: { lastSeen: now },
    })
    .returning({ id: host.id });
  if (!hostRow) throw new Error("upsertHost: missing row");

  const [agentRow] = await db
    .insert(agent)
    .values({ name: agentName, hostId: hostRow.id })
    .onConflictDoUpdate({
      target: [agent.name, agent.hostId],
      set: { lastSeen: now },
    })
    .returning({ id: agent.id });
  if (!agentRow) throw new Error("upsertAgent: missing row");

  return { hostId: hostRow.id, agentId: agentRow.id };
}
