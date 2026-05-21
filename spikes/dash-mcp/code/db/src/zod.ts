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
export const seedProjectInputSchema = createProjectInputSchema.extend({
  reports: z.array(seedReportSchema).default([]),
});
export type SeedProjectInput = z.infer<typeof seedProjectInputSchema>;
