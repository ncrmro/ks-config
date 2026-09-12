import { and, asc, desc, eq, sql } from "drizzle-orm";
import {
  project,
  projectValue,
  projectScope,
  milestone,
  projectRepo,
  projectReport,
  host as hostTable,
  agent as agentTable,
} from "@dash-mcp/db/schema";
import { getDb } from "../db.js";
import { error, json, parseJson, parseQuery } from "../http.js";
import {
  createProjectSchema,
  listProjectsQuerySchema,
  updateProjectSchema,
} from "../validators.js";

export async function listProjects(url: URL): Promise<Response> {
  const q = parseQuery(url, listProjectsQuerySchema);
  if (!q.ok) return q.response;
  const { db } = getDb();
  const where = [];
  if (q.data.status) where.push(eq(project.status, q.data.status));
  const rows = await db
    .select()
    .from(project)
    .where(where.length ? and(...where) : undefined)
    .orderBy(asc(project.slug));
  return json({ projects: rows });
}

export async function getProjectBySlug(slug: string): Promise<Response> {
  const { db } = getDb();
  const [row] = await db
    .select()
    .from(project)
    .where(eq(project.slug, slug))
    .limit(1);
  if (!row) return error("not_found", `project ${slug} not found`, 404);

  const [values, scopes, milestones, repos, reports] = await Promise.all([
    db
      .select()
      .from(projectValue)
      .where(eq(projectValue.projectId, row.id)),
    db
      .select()
      .from(projectScope)
      .where(eq(projectScope.projectId, row.id)),
    db
      .select()
      .from(milestone)
      .where(eq(milestone.projectId, row.id)),
    db
      .select({
        id: projectRepo.id,
        ref: projectRepo.ref,
        url: projectRepo.url,
        label: projectRepo.label,
      })
      .from(projectRepo)
      .where(eq(projectRepo.projectId, row.id)),
    db
      .select({
        id: projectReport.id,
        kind: projectReport.kind,
        summary: projectReport.summary,
        refs: projectReport.refs,
        createdAt: projectReport.createdAt,
        host: hostTable.hostname,
        agent: agentTable.name,
      })
      .from(projectReport)
      .innerJoin(hostTable, eq(hostTable.id, projectReport.hostId))
      .innerJoin(agentTable, eq(agentTable.id, projectReport.agentId))
      .where(eq(projectReport.projectId, row.id))
      .orderBy(desc(projectReport.createdAt)),
  ]);

  return json({
    project: row,
    values: values.map((v) => v.text),
    scopeIn: scopes.filter((s) => s.kind === "in").map((s) => s.text),
    scopeOut: scopes.filter((s) => s.kind === "out").map((s) => s.text),
    milestones,
    repos,
    reports,
  });
}

export async function createProject(req: Request): Promise<Response> {
  const parsed = await parseJson(req, createProjectSchema);
  if (!parsed.ok) return parsed.response;
  const input = parsed.data;
  const { db } = getDb();

  try {
    const [row] = await db
      .insert(project)
      .values({
        slug: input.slug,
        title: input.title,
        purpose: input.purpose,
        status: input.status,
        ownerAgent: input.ownerAgent ?? null,
        missionMdPath: input.missionMdPath ?? null,
      })
      .returning();
    if (!row) return error("insert_failed", "project insert returned no row", 500);

    const values = input.values ?? [];
    const scopeIn = input.scopeIn ?? [];
    const scopeOut = input.scopeOut ?? [];
    const milestones = input.milestones ?? [];
    const repos = input.repos ?? [];

    if (values.length) {
      await db
        .insert(projectValue)
        .values(values.map((text) => ({ projectId: row.id, text })));
    }
    const scopes = [
      ...scopeIn.map((text) => ({ projectId: row.id, kind: "in" as const, text })),
      ...scopeOut.map((text) => ({ projectId: row.id, kind: "out" as const, text })),
    ];
    if (scopes.length) await db.insert(projectScope).values(scopes);

    if (milestones.length) {
      await db.insert(milestone).values(
        milestones.map((m) => ({
          projectId: row.id,
          title: m.title,
          dueAt: m.dueAt ? new Date(m.dueAt) : null,
          status: m.status,
        })),
      );
    }

    if (repos.length) {
      await db.insert(projectRepo).values(
        repos.map((r) => ({
          projectId: row.id,
          ref: r.ref,
          url: r.url,
          label: r.label ?? null,
        })),
      );
    }

    return json({ project: row }, { status: 201 });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (/UNIQUE/i.test(msg)) {
      return error("conflict", `project slug ${input.slug} already exists`, 409);
    }
    return error("insert_failed", msg, 500);
  }
}

export async function updateProject(slug: string, req: Request): Promise<Response> {
  const parsed = await parseJson(req, updateProjectSchema);
  if (!parsed.ok) return parsed.response;
  const patch = parsed.data;
  const { db } = getDb();

  const set: Record<string, unknown> = { updatedAt: sql`(unixepoch())` };
  if (patch.title !== undefined) set.title = patch.title;
  if (patch.purpose !== undefined) set.purpose = patch.purpose;
  if (patch.status !== undefined) set.status = patch.status;
  if (patch.ownerAgent !== undefined) set.ownerAgent = patch.ownerAgent;
  if (patch.missionMdPath !== undefined) set.missionMdPath = patch.missionMdPath;

  const updated = await db
    .update(project)
    .set(set)
    .where(eq(project.slug, slug))
    .returning();
  if (updated.length === 0) {
    return error("not_found", `project ${slug} not found`, 404);
  }
  return json({ project: updated[0] });
}
