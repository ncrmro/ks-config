import { eq } from "drizzle-orm";
import { project, projectReport } from "@dash-mcp/db/schema";
import { getDb } from "../db.js";
import { error, json, parseJson } from "../http.js";
import { createReportSchema } from "../validators.js";
import { upsertHostAndAgent } from "../upsert.js";

export async function createReport(slug: string, req: Request): Promise<Response> {
  const parsed = await parseJson(req, createReportSchema);
  if (!parsed.ok) return parsed.response;
  const input = parsed.data;
  const { db } = getDb();

  const [p] = await db
    .select({ id: project.id })
    .from(project)
    .where(eq(project.slug, slug))
    .limit(1);
  if (!p) return error("not_found", `project ${slug} not found`, 404);

  const { hostId, agentId } = await upsertHostAndAgent(db, input.host, input.agent);

  const [row] = await db
    .insert(projectReport)
    .values({
      projectId: p.id,
      hostId,
      agentId,
      kind: input.kind,
      summary: input.summary,
      refs: input.refs,
    })
    .returning();

  return json({ report: row }, { status: 201 });
}
