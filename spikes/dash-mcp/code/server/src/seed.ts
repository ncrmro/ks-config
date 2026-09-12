import { eq } from "drizzle-orm";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { z } from "zod";
import {
  milestone,
  project,
  projectRepo,
  projectReport,
  projectScope,
  projectValue,
  task,
} from "@dash-mcp/db/schema";
import { seedProjectInputSchema } from "@dash-mcp/db/zod";
import { getDb } from "./db.js";
import { upsertHostAndAgent } from "./upsert.js";

const here = dirname(fileURLToPath(import.meta.url));
const seedPath = resolve(here, "../../db/seeds/projects.json");

const seedArray = z.array(seedProjectInputSchema);

async function main() {
  const raw = JSON.parse(readFileSync(seedPath, "utf8"));
  const items = seedArray.parse(raw);
  const { db, client } = getDb();

  let inserted = 0;
  let skipped = 0;

  for (const item of items) {
    const [existing] = await db
      .select({ id: project.id })
      .from(project)
      .where(eq(project.slug, item.slug))
      .limit(1);
    if (existing) {
      skipped++;
      continue;
    }

    const [row] = await db
      .insert(project)
      .values({
        slug: item.slug,
        title: item.title,
        purpose: item.purpose,
        status: item.status,
        ownerAgent: item.ownerAgent ?? null,
        missionMdPath: item.missionMdPath ?? null,
      })
      .returning();
    if (!row) continue;

    if (item.values.length) {
      await db
        .insert(projectValue)
        .values(item.values.map((text) => ({ projectId: row.id, text })));
    }
    const scopes = [
      ...item.scopeIn.map((text) => ({
        projectId: row.id,
        kind: "in" as const,
        text,
      })),
      ...item.scopeOut.map((text) => ({
        projectId: row.id,
        kind: "out" as const,
        text,
      })),
    ];
    if (scopes.length) await db.insert(projectScope).values(scopes);

    if (item.milestones.length) {
      await db.insert(milestone).values(
        item.milestones.map((m) => ({
          projectId: row.id,
          title: m.title,
          dueAt: m.dueAt ? new Date(m.dueAt) : null,
          status: m.status,
        })),
      );
    }

    if (item.repos.length) {
      await db.insert(projectRepo).values(
        item.repos.map((r) => ({
          projectId: row.id,
          ref: r.ref,
          url: r.url,
          label: r.label ?? null,
        })),
      );
    }

    for (const r of item.reports) {
      const { hostId, agentId } = await upsertHostAndAgent(db, r.host, r.agent);
      await db.insert(projectReport).values({
        projectId: row.id,
        hostId,
        agentId,
        kind: r.kind,
        summary: r.summary,
        refs: r.refs,
      });
    }

    if (item.tasks.length) {
      await db.insert(task).values(
        item.tasks.map((t) => ({
          projectId: row.id,
          milestoneId: t.milestoneId ?? null,
          title: t.title,
          body: t.body ?? null,
          kind: t.kind ?? "other",
          status: t.status ?? "open",
          sourceRef: t.sourceRef ?? null,
          sourceUrl: t.sourceUrl ?? null,
          requester: t.requester ?? null,
          assigneeAgent: t.assigneeAgent ?? null,
          dueAt: t.dueAt ? new Date(t.dueAt) : null,
        })),
      );
    }

    inserted++;
  }

  console.error(`[seed] inserted=${inserted} skipped=${skipped} total=${items.length}`);
  client.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
