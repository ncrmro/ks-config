import { and, asc, desc, eq, sql } from "drizzle-orm";
import {
  mission,
  missionValue,
  missionScope,
  missionMilestone,
  missionRepo,
  missionReport,
  host as hostTable,
  agent as agentTable,
} from "@dash-mcp/db/schema";
import { getDb } from "../db.js";
import { error, json, parseJson, parseQuery } from "../http.js";
import {
  createMissionSchema,
  listMissionsQuerySchema,
  updateMissionSchema,
} from "../validators.js";

export async function listMissions(url: URL): Promise<Response> {
  const q = parseQuery(url, listMissionsQuerySchema);
  if (!q.ok) return q.response;
  const { db } = getDb();
  const where = [];
  if (q.data.project) where.push(eq(mission.project, q.data.project));
  if (q.data.status) where.push(eq(mission.status, q.data.status));
  const rows = await db
    .select()
    .from(mission)
    .where(where.length ? and(...where) : undefined)
    .orderBy(asc(mission.project), asc(mission.slug));
  return json({ missions: rows });
}

export async function getMissionBySlug(slug: string): Promise<Response> {
  const { db } = getDb();
  const [row] = await db
    .select()
    .from(mission)
    .where(eq(mission.slug, slug))
    .limit(1);
  if (!row) return error("not_found", `mission ${slug} not found`, 404);

  const [values, scopes, milestones, repos, reports] = await Promise.all([
    db
      .select()
      .from(missionValue)
      .where(eq(missionValue.missionId, row.id)),
    db
      .select()
      .from(missionScope)
      .where(eq(missionScope.missionId, row.id)),
    db
      .select()
      .from(missionMilestone)
      .where(eq(missionMilestone.missionId, row.id)),
    db
      .select({
        id: missionRepo.id,
        ref: missionRepo.ref,
        url: missionRepo.url,
        label: missionRepo.label,
      })
      .from(missionRepo)
      .where(eq(missionRepo.missionId, row.id)),
    db
      .select({
        id: missionReport.id,
        kind: missionReport.kind,
        summary: missionReport.summary,
        refs: missionReport.refs,
        createdAt: missionReport.createdAt,
        host: hostTable.hostname,
        agent: agentTable.name,
      })
      .from(missionReport)
      .innerJoin(hostTable, eq(hostTable.id, missionReport.hostId))
      .innerJoin(agentTable, eq(agentTable.id, missionReport.agentId))
      .where(eq(missionReport.missionId, row.id))
      .orderBy(desc(missionReport.createdAt)),
  ]);

  return json({
    mission: row,
    values: values.map((v) => v.text),
    scopeIn: scopes.filter((s) => s.kind === "in").map((s) => s.text),
    scopeOut: scopes.filter((s) => s.kind === "out").map((s) => s.text),
    milestones,
    repos,
    reports,
  });
}

export async function createMission(req: Request): Promise<Response> {
  const parsed = await parseJson(req, createMissionSchema);
  if (!parsed.ok) return parsed.response;
  const input = parsed.data;
  const { db } = getDb();

  try {
    const [row] = await db
      .insert(mission)
      .values({
        slug: input.slug,
        project: input.project,
        title: input.title,
        purpose: input.purpose,
        status: input.status,
        ownerAgent: input.ownerAgent ?? null,
      })
      .returning();
    if (!row) return error("insert_failed", "mission insert returned no row", 500);

    const values = input.values ?? [];
    const scopeIn = input.scopeIn ?? [];
    const scopeOut = input.scopeOut ?? [];
    const milestones = input.milestones ?? [];
    const repos = input.repos ?? [];

    if (values.length) {
      await db
        .insert(missionValue)
        .values(values.map((text) => ({ missionId: row.id, text })));
    }
    const scopes = [
      ...scopeIn.map((text) => ({ missionId: row.id, kind: "in" as const, text })),
      ...scopeOut.map((text) => ({ missionId: row.id, kind: "out" as const, text })),
    ];
    if (scopes.length) await db.insert(missionScope).values(scopes);

    if (milestones.length) {
      await db.insert(missionMilestone).values(
        milestones.map((m) => ({
          missionId: row.id,
          title: m.title,
          dueAt: m.dueAt ? new Date(m.dueAt) : null,
          status: m.status,
        })),
      );
    }

    if (repos.length) {
      await db.insert(missionRepo).values(
        repos.map((r) => ({
          missionId: row.id,
          ref: r.ref,
          url: r.url,
          label: r.label ?? null,
        })),
      );
    }

    return json({ mission: row }, { status: 201 });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (/UNIQUE/i.test(msg)) {
      return error("conflict", `mission slug ${input.slug} already exists`, 409);
    }
    return error("insert_failed", msg, 500);
  }
}

export async function updateMission(slug: string, req: Request): Promise<Response> {
  const parsed = await parseJson(req, updateMissionSchema);
  if (!parsed.ok) return parsed.response;
  const patch = parsed.data;
  const { db } = getDb();

  const set: Record<string, unknown> = { updatedAt: sql`(unixepoch())` };
  if (patch.title !== undefined) set.title = patch.title;
  if (patch.purpose !== undefined) set.purpose = patch.purpose;
  if (patch.status !== undefined) set.status = patch.status;
  if (patch.ownerAgent !== undefined) set.ownerAgent = patch.ownerAgent;

  const updated = await db
    .update(mission)
    .set(set)
    .where(eq(mission.slug, slug))
    .returning();
  if (updated.length === 0) {
    return error("not_found", `mission ${slug} not found`, 404);
  }
  return json({ mission: updated[0] });
}
