// Zod schemas derived from the Drizzle tables via drizzle-zod. These are the
// single source of truth for request/response shapes — every consumer (server
// validators, MCP tool inputs, web client types) imports from here.
import { z } from "zod";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import {
  agent,
  host,
  milestone,
  project,
  projectRepo,
  projectReport,
  projectScope,
  projectValue,
  task,
} from "./schema.js";

// Selects — outbound payloads.
export const projectSelectSchema = createSelectSchema(project);
export const projectReportSelectSchema = createSelectSchema(projectReport);
export const milestoneSelectSchema = createSelectSchema(milestone);
export const projectRepoSelectSchema = createSelectSchema(projectRepo);
export const hostSelectSchema = createSelectSchema(host);
export const agentSelectSchema = createSelectSchema(agent);

// Inserts — base shapes used to build the public create/update API.
export const projectInsertSchema = createInsertSchema(project, {
  slug: (s) =>
    s.regex(/^[a-z0-9][a-z0-9._-]*$/, "slug must be kebab/dot/underscore lowercase"),
});

export const projectValueInsertSchema = createInsertSchema(projectValue, {
  text: (s) => s.min(1),
});
export const projectScopeInsertSchema = createInsertSchema(projectScope, {
  text: (s) => s.min(1),
});
export const milestoneInsertSchema = createInsertSchema(milestone, {
  title: (s) => s.min(1),
});

// Normalized ref per process.keystone-development rules 16-18.
const refRegex = /^(gh|fj):[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+(#\d+)?$/;
export const projectRepoInsertSchema = createInsertSchema(projectRepo, {
  ref: (s) => s.regex(refRegex, "ref must be gh:owner/repo[#n] or fj:owner/repo[#n]"),
  url: (s) => s.url(),
});

export const projectReportInsertSchema = createInsertSchema(projectReport, {
  summary: (s) => s.min(1),
});

// Public API shape: project_id is filled in by the server, so the API takes
// only the parts a client actually supplies. dueAt is exposed as an ISO-8601
// string (and serialized to a Date server-side) because z.toJSONSchema cannot
// represent JS Date values.
const milestoneInput = milestoneInsertSchema
  .omit({ id: true, projectId: true, dueAt: true })
  .extend({
    dueAt: z.iso.datetime().nullish(),
  });
const repoInput = projectRepoInsertSchema.omit({
  id: true,
  projectId: true,
});

export const createProjectInputSchema = projectInsertSchema
  .omit({ id: true, createdAt: true, updatedAt: true })
  .extend({
    purpose: z.string().default(""),
    values: z.array(z.string().min(1)).default([]),
    scopeIn: z.array(z.string().min(1)).default([]),
    scopeOut: z.array(z.string().min(1)).default([]),
    milestones: z.array(milestoneInput).default([]),
    repos: z.array(repoInput).default([]),
  });
export type CreateProjectInput = z.infer<typeof createProjectInputSchema>;

export const updateProjectInputSchema = projectInsertSchema
  .pick({ title: true, purpose: true, status: true, ownerAgent: true, missionMdPath: true })
  .partial();
export type UpdateProjectInput = z.infer<typeof updateProjectInputSchema>;

export const createReportInputSchema = z.object({
  host: z.string().min(1),
  agent: z.string().min(1),
  kind: projectReportInsertSchema.shape.kind,
  summary: z.string().min(1),
  refs: z.array(z.string().min(1)).default([]),
});
export type CreateReportInput = z.infer<typeof createReportInputSchema>;

export const listProjectsQuerySchema = z.object({
  status: projectInsertSchema.shape.status.optional(),
});

// Seed-only shape: superset of the public create-project API that also lets
// fixture data attribute existing fleet activity (host + agent reports) so the
// dashboard has something to show before any live agent has connected.
export const seedReportSchema = z.object({
  host: z.string().min(1),
  agent: z.string().min(1),
  kind: projectReportInsertSchema.shape.kind,
  summary: z.string().min(1),
  refs: z.array(z.string().min(1)).default([]),
});
// Cross-provider task source ref. One regex covers all the prefixes
// documented in docs/proposals.md.
const sourceRefRegex =
  /^(gh|fj|slack|mail|cal|agent|note):[^\s].*$/;

export const taskSelectSchema = createSelectSchema(task);
export const taskInsertSchema = createInsertSchema(task, {
  title: (s) => s.min(1),
  sourceRef: (s) =>
    s.regex(
      sourceRefRegex,
      "source_ref must use a known prefix: gh:/fj:/slack:/mail:/cal:/agent:/note:",
    ),
  sourceUrl: (s) => s.url(),
});

// Public create-task input. Server fills timestamps + id.
export const createTaskInputSchema = taskInsertSchema
  .omit({ id: true, createdAt: true, updatedAt: true, projectId: true, dueAt: true })
  .extend({
    projectSlug: z.string().min(1),
    milestoneId: z.number().int().nullish(),
    dueAt: z.iso.datetime().nullish(),
  });
export type CreateTaskInput = z.infer<typeof createTaskInputSchema>;

export const updateTaskInputSchema = taskInsertSchema
  .pick({
    title: true,
    body: true,
    kind: true,
    status: true,
    sourceRef: true,
    sourceUrl: true,
    requester: true,
    assigneeAgent: true,
    milestoneId: true,
  })
  .partial()
  .extend({ dueAt: z.iso.datetime().nullish() });
export type UpdateTaskInput = z.infer<typeof updateTaskInputSchema>;

export const listTasksQuerySchema = z.object({
  project: z.string().optional(),
  assignee: z.string().optional(),
  kind: taskInsertSchema.shape.kind.optional(),
  status: taskInsertSchema.shape.status.optional(),
});
export type ListTasksQuery = z.infer<typeof listTasksQuerySchema>;

// Seed-only shape: tasks are inlined inside a project so fixture data can
// attribute realistic assigner/assignee identities.
export const seedTaskSchema = createTaskInputSchema.omit({
  projectSlug: true,
});

export const seedProjectInputSchema = createProjectInputSchema.extend({
  reports: z.array(seedReportSchema).default([]),
  tasks: z.array(seedTaskSchema).default([]),
});
export type SeedProjectInput = z.infer<typeof seedProjectInputSchema>;
