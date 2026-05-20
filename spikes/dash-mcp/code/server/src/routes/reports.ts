import { eq } from "drizzle-orm";
import { mission, missionReport } from "@dash-mcp/db/schema";
import { getDb } from "../db.js";
import { error, json, parseJson } from "../http.js";
import { createReportSchema } from "../validators.js";
import { upsertHostAndAgent } from "../upsert.js";

export async function createReport(slug: string, req: Request): Promise<Response> {
  const parsed = await parseJson(req, createReportSchema);
  if (!parsed.ok) return parsed.response;
  const input = parsed.data;
  const { db } = getDb();

  const [m] = await db
    .select({ id: mission.id })
    .from(mission)
    .where(eq(mission.slug, slug))
    .limit(1);
  if (!m) return error("not_found", `mission ${slug} not found`, 404);

  const { hostId, agentId } = await upsertHostAndAgent(db, input.host, input.agent);

  const [row] = await db
    .insert(missionReport)
    .values({
      missionId: m.id,
      hostId,
      agentId,
      kind: input.kind,
      summary: input.summary,
      refs: input.refs,
    })
    .returning();

  return json({ report: row }, { status: 201 });
}
