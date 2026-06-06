import { and, desc, eq } from "drizzle-orm";
import { project, task } from "@dash-mcp/db/schema";
import {
  createTaskInputSchema,
  listTasksQuerySchema,
  updateTaskInputSchema,
} from "@dash-mcp/db/zod";
import { getDb } from "../db.js";
import { error, json, parseJson, parseQuery } from "../http.js";

export async function listTasks(url: URL): Promise<Response> {
  const q = parseQuery(url, listTasksQuerySchema);
  if (!q.ok) return q.response;
  const { db } = getDb();
  const where = [];
  if (q.data.assignee) where.push(eq(task.assigneeAgent, q.data.assignee));
  if (q.data.kind) where.push(eq(task.kind, q.data.kind));
  if (q.data.status) where.push(eq(task.status, q.data.status));

  let rows;
  if (q.data.project) {
    const [p] = await db
      .select({ id: project.id })
      .from(project)
      .where(eq(project.slug, q.data.project))
      .limit(1);
    if (!p) return json({ tasks: [] });
    where.push(eq(task.projectId, p.id));
  }

  rows = await db
    .select({
      id: task.id,
      projectId: task.projectId,
      projectSlug: project.slug,
      milestoneId: task.milestoneId,
      title: task.title,
      body: task.body,
      kind: task.kind,
      status: task.status,
      sourceRef: task.sourceRef,
      sourceUrl: task.sourceUrl,
      requester: task.requester,
      assigneeAgent: task.assigneeAgent,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    })
    .from(task)
    .innerJoin(project, eq(project.id, task.projectId))
    .where(where.length ? and(...where) : undefined)
    .orderBy(desc(task.updatedAt));

  return json({ tasks: rows });
}

export async function getTask(id: number): Promise<Response> {
  const { db } = getDb();
  const [row] = await db
    .select({
      id: task.id,
      projectId: task.projectId,
      projectSlug: project.slug,
      milestoneId: task.milestoneId,
      title: task.title,
      body: task.body,
      kind: task.kind,
      status: task.status,
      sourceRef: task.sourceRef,
      sourceUrl: task.sourceUrl,
      requester: task.requester,
      assigneeAgent: task.assigneeAgent,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    })
    .from(task)
    .innerJoin(project, eq(project.id, task.projectId))
    .where(eq(task.id, id))
    .limit(1);
  if (!row) return error("not_found", `task ${id} not found`, 404);
  return json({ task: row });
}

export async function createTask(req: Request): Promise<Response> {
  const parsed = await parseJson(req, createTaskInputSchema);
  if (!parsed.ok) return parsed.response;
  const input = parsed.data;
  const { db } = getDb();

  const [p] = await db
    .select({ id: project.id })
    .from(project)
    .where(eq(project.slug, input.projectSlug))
    .limit(1);
  if (!p) return error("not_found", `project ${input.projectSlug} not found`, 404);

  try {
    const [row] = await db
      .insert(task)
      .values({
        projectId: p.id,
        milestoneId: input.milestoneId ?? null,
        title: input.title,
        body: input.body ?? null,
        kind: input.kind ?? "other",
        status: input.status ?? "open",
        sourceRef: input.sourceRef ?? null,
        sourceUrl: input.sourceUrl ?? null,
        requester: input.requester ?? null,
        assigneeAgent: input.assigneeAgent ?? null,
        dueAt: input.dueAt ? new Date(input.dueAt) : null,
      })
      .returning();
    return json({ task: row }, { status: 201 });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (/UNIQUE/i.test(msg) && /source_ref/i.test(msg)) {
      return error(
        "conflict",
        `task with source_ref ${input.sourceRef} already exists`,
        409,
      );
    }
    return error("insert_failed", msg, 500);
  }
}

export async function updateTask(id: number, req: Request): Promise<Response> {
  const parsed = await parseJson(req, updateTaskInputSchema);
  if (!parsed.ok) return parsed.response;
  const patch = parsed.data;
  const { db } = getDb();

  const set: Record<string, unknown> = { updatedAt: new Date() };
  if (patch.title !== undefined) set.title = patch.title;
  if (patch.body !== undefined) set.body = patch.body;
  if (patch.kind !== undefined) set.kind = patch.kind;
  if (patch.status !== undefined) set.status = patch.status;
  if (patch.sourceRef !== undefined) set.sourceRef = patch.sourceRef;
  if (patch.sourceUrl !== undefined) set.sourceUrl = patch.sourceUrl;
  if (patch.requester !== undefined) set.requester = patch.requester;
  if (patch.assigneeAgent !== undefined) set.assigneeAgent = patch.assigneeAgent;
  if (patch.milestoneId !== undefined) set.milestoneId = patch.milestoneId;
  if (patch.dueAt !== undefined) set.dueAt = patch.dueAt ? new Date(patch.dueAt) : null;

  const updated = await db.update(task).set(set).where(eq(task.id, id)).returning();
  if (updated.length === 0) return error("not_found", `task ${id} not found`, 404);
  return json({ task: updated[0] });
}
