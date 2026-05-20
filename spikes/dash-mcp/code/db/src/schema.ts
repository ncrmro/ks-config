import { sql } from "drizzle-orm";
import {
  integer,
  sqliteTable,
  text,
  uniqueIndex,
  index,
} from "drizzle-orm/sqlite-core";

const now = sql`(unixepoch())`;

export const missionStatus = [
  "proposed",
  "active",
  "blocked",
  "done",
  "archived",
] as const;
export type MissionStatus = (typeof missionStatus)[number];

export const reportKind = [
  "work_started",
  "work_update",
  "blocked",
  "done",
  "note",
] as const;
export type ReportKind = (typeof reportKind)[number];

export const scopeKind = ["in", "out"] as const;
export type ScopeKind = (typeof scopeKind)[number];

export const milestoneStatus = [
  "planned",
  "in_progress",
  "blocked",
  "done",
  "cancelled",
] as const;
export type MilestoneStatus = (typeof milestoneStatus)[number];

export const host = sqliteTable(
  "host",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    hostname: text("hostname").notNull(),
    firstSeen: integer("first_seen", { mode: "timestamp" })
      .notNull()
      .default(now),
    lastSeen: integer("last_seen", { mode: "timestamp" })
      .notNull()
      .default(now),
  },
  (t) => ({
    hostnameUq: uniqueIndex("host_hostname_uq").on(t.hostname),
  }),
);

export const agent = sqliteTable(
  "agent",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    name: text("name").notNull(),
    hostId: integer("host_id")
      .notNull()
      .references(() => host.id, { onDelete: "cascade" }),
    firstSeen: integer("first_seen", { mode: "timestamp" })
      .notNull()
      .default(now),
    lastSeen: integer("last_seen", { mode: "timestamp" })
      .notNull()
      .default(now),
  },
  (t) => ({
    nameHostUq: uniqueIndex("agent_name_host_uq").on(t.name, t.hostId),
  }),
);

export const mission = sqliteTable(
  "mission",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    slug: text("slug").notNull(),
    project: text("project").notNull(),
    title: text("title").notNull(),
    purpose: text("purpose").notNull().default(""),
    status: text("status", { enum: missionStatus }).notNull().default("proposed"),
    ownerAgent: text("owner_agent"),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .default(now),
    updatedAt: integer("updated_at", { mode: "timestamp" })
      .notNull()
      .default(now),
  },
  (t) => ({
    slugUq: uniqueIndex("mission_slug_uq").on(t.slug),
    projectIdx: index("mission_project_idx").on(t.project),
    statusIdx: index("mission_status_idx").on(t.status),
  }),
);

export const missionValue = sqliteTable("mission_value", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  missionId: integer("mission_id")
    .notNull()
    .references(() => mission.id, { onDelete: "cascade" }),
  text: text("text").notNull(),
});

export const missionScope = sqliteTable("mission_scope", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  missionId: integer("mission_id")
    .notNull()
    .references(() => mission.id, { onDelete: "cascade" }),
  kind: text("kind", { enum: scopeKind }).notNull(),
  text: text("text").notNull(),
});

export const missionRepo = sqliteTable(
  "mission_repo",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    missionId: integer("mission_id")
      .notNull()
      .references(() => mission.id, { onDelete: "cascade" }),
    // Normalized ref per process.keystone-development rules 16-18:
    //   gh:<owner>/<repo>  or  fj:<owner>/<repo>
    ref: text("ref").notNull(),
    url: text("url").notNull(),
    label: text("label"),
  },
  (t) => ({
    refIdx: index("mission_repo_ref_idx").on(t.missionId, t.ref),
  }),
);

export const missionMilestone = sqliteTable("mission_milestone", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  missionId: integer("mission_id")
    .notNull()
    .references(() => mission.id, { onDelete: "cascade" }),
  title: text("title").notNull(),
  dueAt: integer("due_at", { mode: "timestamp" }),
  status: text("status", { enum: milestoneStatus })
    .notNull()
    .default("planned"),
});

export const missionReport = sqliteTable(
  "mission_report",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    missionId: integer("mission_id")
      .notNull()
      .references(() => mission.id, { onDelete: "cascade" }),
    hostId: integer("host_id")
      .notNull()
      .references(() => host.id),
    agentId: integer("agent_id")
      .notNull()
      .references(() => agent.id),
    kind: text("kind", { enum: reportKind }).notNull(),
    summary: text("summary").notNull(),
    refs: text("refs", { mode: "json" }).$type<string[]>().notNull().default(
      sql`'[]'`,
    ),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .default(now),
  },
  (t) => ({
    missionIdx: index("mission_report_mission_idx").on(t.missionId, t.createdAt),
    hostIdx: index("mission_report_host_idx").on(t.hostId, t.createdAt),
    agentIdx: index("mission_report_agent_idx").on(t.agentId, t.createdAt),
  }),
);

export type Mission = typeof mission.$inferSelect;
export type NewMission = typeof mission.$inferInsert;
export type MissionReport = typeof missionReport.$inferSelect;
export type NewMissionReport = typeof missionReport.$inferInsert;
export type MissionRepo = typeof missionRepo.$inferSelect;
export type NewMissionRepo = typeof missionRepo.$inferInsert;
export type MissionMilestone = typeof missionMilestone.$inferSelect;
export type Host = typeof host.$inferSelect;
export type Agent = typeof agent.$inferSelect;
