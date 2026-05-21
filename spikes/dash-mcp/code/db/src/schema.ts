import { sql } from "drizzle-orm";
import {
  integer,
  sqliteTable,
  text,
  uniqueIndex,
  index,
} from "drizzle-orm/sqlite-core";

const now = sql`(unixepoch())`;

export const projectStatus = [
  "proposed",
  "active",
  "blocked",
  "done",
  "archived",
] as const;
export type ProjectStatus = (typeof projectStatus)[number];

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

export const project = sqliteTable(
  "project",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    slug: text("slug").notNull(),
    title: text("title").notNull(),
    purpose: text("purpose").notNull().default(""),
    status: text("status", { enum: projectStatus }).notNull().default("proposed"),
    ownerAgent: text("owner_agent"),
    // Pointer to the Keystone-voice narrative in the notebook
    // (e.g. ~/notes/projects/<slug>/mission.md). Optional — the project
    // exists with or without one.
    missionMdPath: text("mission_md_path"),
    createdAt: integer("created_at", { mode: "timestamp" })
      .notNull()
      .default(now),
    updatedAt: integer("updated_at", { mode: "timestamp" })
      .notNull()
      .default(now),
  },
  (t) => ({
    slugUq: uniqueIndex("project_slug_uq").on(t.slug),
    statusIdx: index("project_status_idx").on(t.status),
  }),
);

export const projectValue = sqliteTable("project_value", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  projectId: integer("project_id")
    .notNull()
    .references(() => project.id, { onDelete: "cascade" }),
  text: text("text").notNull(),
});

export const projectScope = sqliteTable("project_scope", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  projectId: integer("project_id")
    .notNull()
    .references(() => project.id, { onDelete: "cascade" }),
  kind: text("kind", { enum: scopeKind }).notNull(),
  text: text("text").notNull(),
});

export const projectRepo = sqliteTable(
  "project_repo",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    projectId: integer("project_id")
      .notNull()
      .references(() => project.id, { onDelete: "cascade" }),
    // Normalized ref per process.keystone-development rules 16-18:
    //   gh:<owner>/<repo>  or  fj:<owner>/<repo>
    ref: text("ref").notNull(),
    url: text("url").notNull(),
    label: text("label"),
  },
  (t) => ({
    refIdx: index("project_repo_ref_idx").on(t.projectId, t.ref),
  }),
);

export const milestone = sqliteTable("milestone", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  projectId: integer("project_id")
    .notNull()
    .references(() => project.id, { onDelete: "cascade" }),
  title: text("title").notNull(),
  dueAt: integer("due_at", { mode: "timestamp" }),
  status: text("status", { enum: milestoneStatus })
    .notNull()
    .default("planned"),
});

export const projectReport = sqliteTable(
  "project_report",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    projectId: integer("project_id")
      .notNull()
      .references(() => project.id, { onDelete: "cascade" }),
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
    projectIdx: index("project_report_project_idx").on(t.projectId, t.createdAt),
    hostIdx: index("project_report_host_idx").on(t.hostId, t.createdAt),
    agentIdx: index("project_report_agent_idx").on(t.agentId, t.createdAt),
  }),
);

export type Project = typeof project.$inferSelect;
export type NewProject = typeof project.$inferInsert;
export type ProjectReport = typeof projectReport.$inferSelect;
export type NewProjectReport = typeof projectReport.$inferInsert;
export type ProjectRepo = typeof projectRepo.$inferSelect;
export type NewProjectRepo = typeof projectRepo.$inferInsert;
export type Milestone = typeof milestone.$inferSelect;
export type Host = typeof host.$inferSelect;
export type Agent = typeof agent.$inferSelect;
