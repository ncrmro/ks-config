import { eq } from "drizzle-orm";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { z } from "zod";
import {
  mission,
  missionMilestone,
  missionRepo,
  missionReport,
  missionScope,
  missionValue,
} from "@dash-mcp/db/schema";
import { seedMissionInputSchema } from "@dash-mcp/db/zod";
import { getDb } from "./db.js";
import { upsertHostAndAgent } from "./upsert.js";

const here = dirname(fileURLToPath(import.meta.url));
const seedPath = resolve(here, "../../db/seeds/missions.json");

const seedArray = z.array(seedMissionInputSchema);

async function main() {
  const raw = JSON.parse(readFileSync(seedPath, "utf8"));
  const items = seedArray.parse(raw);
  const { db, client } = getDb();

  let inserted = 0;
  let skipped = 0;

  for (const item of items) {
    const [existing] = await db
      .select({ id: mission.id })
      .from(mission)
      .where(eq(mission.slug, item.slug))
      .limit(1);
    if (existing) {
      skipped++;
      continue;
    }

    const [row] = await db
      .insert(mission)
      .values({
        slug: item.slug,
        project: item.project,
        title: item.title,
        purpose: item.purpose,
        status: item.status,
        ownerAgent: item.ownerAgent ?? null,
      })
      .returning();
    if (!row) continue;

    if (item.values.length) {
      await db
        .insert(missionValue)
        .values(item.values.map((text) => ({ missionId: row.id, text })));
    }
    const scopes = [
      ...item.scopeIn.map((text) => ({
        missionId: row.id,
        kind: "in" as const,
        text,
      })),
      ...item.scopeOut.map((text) => ({
        missionId: row.id,
        kind: "out" as const,
        text,
      })),
    ];
    if (scopes.length) await db.insert(missionScope).values(scopes);

    if (item.milestones.length) {
      await db.insert(missionMilestone).values(
        item.milestones.map((m) => ({
          missionId: row.id,
          title: m.title,
          dueAt: m.dueAt ? new Date(m.dueAt) : null,
          status: m.status,
        })),
      );
    }

    if (item.repos.length) {
      await db.insert(missionRepo).values(
        item.repos.map((r) => ({
          missionId: row.id,
          ref: r.ref,
          url: r.url,
          label: r.label ?? null,
        })),
      );
    }

    for (const r of item.reports) {
      const { hostId, agentId } = await upsertHostAndAgent(db, r.host, r.agent);
      await db.insert(missionReport).values({
        missionId: row.id,
        hostId,
        agentId,
        kind: r.kind,
        summary: r.summary,
        refs: r.refs,
      });
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
