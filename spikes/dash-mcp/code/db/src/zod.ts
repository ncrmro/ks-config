// Zod schemas derived from the Drizzle tables via drizzle-zod. These are the
// single source of truth for request/response shapes — every consumer (server
// validators, MCP tool inputs, web client types) imports from here.
import { z } from "zod";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import {
  agent,
  host,
  mission,
  missionMilestone,
  missionRepo,
  missionReport,
  missionScope,
  missionValue,
} from "./schema.js";

// Selects — outbound payloads.
export const missionSelectSchema = createSelectSchema(mission);
export const missionReportSelectSchema = createSelectSchema(missionReport);
export const missionMilestoneSelectSchema = createSelectSchema(missionMilestone);
export const missionRepoSelectSchema = createSelectSchema(missionRepo);
export const hostSelectSchema = createSelectSchema(host);
export const agentSelectSchema = createSelectSchema(agent);

// Inserts — base shapes used to build the public create/update API.
export const missionInsertSchema = createInsertSchema(mission, {
  slug: (s) =>
    s.regex(/^[a-z0-9][a-z0-9._-]*$/, "slug must be kebab/dot/underscore lowercase"),
});

export const missionValueInsertSchema = createInsertSchema(missionValue, {
  text: (s) => s.min(1),
});
export const missionScopeInsertSchema = createInsertSchema(missionScope, {
  text: (s) => s.min(1),
});
export const missionMilestoneInsertSchema = createInsertSchema(missionMilestone, {
  title: (s) => s.min(1),
});

// Normalized ref per process.keystone-development rules 16-18.
const refRegex = /^(gh|fj):[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+(#\d+)?$/;
export const missionRepoInsertSchema = createInsertSchema(missionRepo, {
  ref: (s) => s.regex(refRegex, "ref must be gh:owner/repo[#n] or fj:owner/repo[#n]"),
  url: (s) => s.url(),
});

export const missionReportInsertSchema = createInsertSchema(missionReport, {
  summary: (s) => s.min(1),
});

// Public API shape: mission_id is filled in by the server, so the API takes
// only the parts a client actually supplies. dueAt is exposed as an ISO-8601
// string (and serialized to a Date server-side) because z.toJSONSchema cannot
// represent JS Date values.
const milestoneInput = missionMilestoneInsertSchema
  .omit({ id: true, missionId: true, dueAt: true })
  .extend({
    dueAt: z.iso.datetime().nullish(),
  });
const repoInput = missionRepoInsertSchema.omit({
  id: true,
  missionId: true,
});

export const createMissionInputSchema = missionInsertSchema
  .omit({ id: true, createdAt: true, updatedAt: true })
  .extend({
    purpose: z.string().default(""),
    values: z.array(z.string().min(1)).default([]),
    scopeIn: z.array(z.string().min(1)).default([]),
    scopeOut: z.array(z.string().min(1)).default([]),
    milestones: z.array(milestoneInput).default([]),
    repos: z.array(repoInput).default([]),
  });
export type CreateMissionInput = z.infer<typeof createMissionInputSchema>;

// Seed-only shape: superset of the public create-mission API that also lets
// fixture data attribute existing fleet activity (host + agent reports) so the
// dashboard has something to show before any live agent has connected.
export const seedReportSchema = z.object({
  host: z.string().min(1),
  agent: z.string().min(1),
  kind: missionReportInsertSchema.shape.kind,
  summary: z.string().min(1),
  refs: z.array(z.string().min(1)).default([]),
});
export const seedMissionInputSchema = createMissionInputSchema.extend({
  reports: z.array(seedReportSchema).default([]),
});
export type SeedMissionInput = z.infer<typeof seedMissionInputSchema>;

export const updateMissionInputSchema = missionInsertSchema
  .pick({ title: true, purpose: true, status: true, ownerAgent: true })
  .partial();
export type UpdateMissionInput = z.infer<typeof updateMissionInputSchema>;

export const createReportInputSchema = z.object({
  host: z.string().min(1),
  agent: z.string().min(1),
  kind: missionReportInsertSchema.shape.kind,
  summary: z.string().min(1),
  refs: z.array(z.string().min(1)).default([]),
});
export type CreateReportInput = z.infer<typeof createReportInputSchema>;

export const listMissionsQuerySchema = z.object({
  project: z.string().optional(),
  status: missionInsertSchema.shape.status.optional(),
});
