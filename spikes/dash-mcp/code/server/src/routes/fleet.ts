import { desc, eq } from "drizzle-orm";
import { host, agent } from "@dash-mcp/db/schema";
import { getDb } from "../db.js";
import { json } from "../http.js";

export async function listHosts(): Promise<Response> {
  const { db } = getDb();
  const rows = await db.select().from(host).orderBy(desc(host.lastSeen));
  return json({ hosts: rows });
}

export async function listAgents(): Promise<Response> {
  const { db } = getDb();
  const rows = await db
    .select({
      id: agent.id,
      name: agent.name,
      host: host.hostname,
      firstSeen: agent.firstSeen,
      lastSeen: agent.lastSeen,
    })
    .from(agent)
    .innerJoin(host, eq(host.id, agent.hostId))
    .orderBy(desc(agent.lastSeen));
  return json({ agents: rows });
}
