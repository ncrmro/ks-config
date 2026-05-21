import { z } from "zod";
import {
  createProjectInputSchema,
  updateProjectInputSchema,
  projectInsertSchema,
  projectReportInsertSchema,
} from "@dash-mcp/db/zod";
import { api } from "./api.js";
import { resolveIdentity } from "./identity.js";

const projectStatusSchema = projectInsertSchema.shape.status;
const reportKindSchema = projectReportInsertSchema.shape.kind;

export const tools = {
  project_list: {
    description:
      "List projects across the fleet. Optionally filter by status.",
    input: z.object({
      status: projectStatusSchema.optional(),
    }),
    run: async (args: { status?: string }) => api.listProjects(args),
  },

  project_get: {
    description:
      "Get a single project by slug, including its values, scope, milestones, repos, and report timeline.",
    input: z.object({ slug: z.string() }),
    run: async (args: { slug: string }) => api.getProject(args.slug),
  },

  project_create: {
    description:
      "Create a new project. Optional missionMdPath points to the Keystone-voice narrative in the notebook (e.g. projects/<slug>/mission.md) that owns the Purpose / Values / Scope statement; the project row mirrors a dashboard-friendly subset.",
    input: createProjectInputSchema,
    run: async (args: unknown) => api.createProject(args),
  },

  project_update: {
    description: "Patch a project's title/purpose/status/owner/missionMdPath.",
    input: z.object({
      slug: z.string(),
      patch: updateProjectInputSchema,
    }),
    run: async (args: { slug: string; patch: unknown }) =>
      api.updateProject(args.slug, args.patch),
  },

  project_report: {
    description:
      "Append a progress report against a project. host and agent are auto-resolved from $DASH_MCP_HOST/$HOSTNAME and $DASH_MCP_AGENT/$KS_AGENT/$USER unless explicitly overridden.",
    input: z.object({
      slug: z.string(),
      kind: reportKindSchema,
      summary: z.string(),
      refs: z.array(z.string()).default([]),
      host: z.string().optional(),
      agent: z.string().optional(),
    }),
    run: async (args: {
      slug: string;
      kind: string;
      summary: string;
      refs?: string[];
      host?: string;
      agent?: string;
    }) => {
      const ident = resolveIdentity();
      return api.createReport(args.slug, {
        host: args.host ?? ident.host,
        agent: args.agent ?? ident.agent,
        kind: args.kind,
        summary: args.summary,
        refs: args.refs ?? [],
      });
    },
  },
} as const;

export type ToolName = keyof typeof tools;
