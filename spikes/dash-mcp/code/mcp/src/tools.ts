import { z } from "zod";
import {
  createMissionInputSchema,
  updateMissionInputSchema,
  missionInsertSchema,
  missionReportInsertSchema,
} from "@dash-mcp/db/zod";
import { api } from "./api.js";
import { resolveIdentity } from "./identity.js";

const missionStatusSchema = missionInsertSchema.shape.status;
const reportKindSchema = missionReportInsertSchema.shape.kind;

export const tools = {
  mission_list: {
    description:
      "List missions across the fleet. Optionally filter by project or status.",
    input: z.object({
      project: z.string().optional(),
      status: missionStatusSchema.optional(),
    }),
    run: async (args: { project?: string; status?: string }) =>
      api.listMissions(args),
  },

  mission_get: {
    description:
      "Get a single mission by slug, including its values, scope, milestones, repos, and report timeline.",
    input: z.object({ slug: z.string() }),
    run: async (args: { slug: string }) => api.getMission(args.slug),
  },

  mission_create: {
    description:
      "Create a new mission. Mirrors the shape of ~/notes/projects/<name>/mission.md (purpose / values / scope) plus dashboard fields (status, owner, milestones, repos).",
    input: createMissionInputSchema,
    run: async (args: unknown) => api.createMission(args),
  },

  mission_update: {
    description: "Patch a mission's title/purpose/status/owner.",
    input: z.object({
      slug: z.string(),
      patch: updateMissionInputSchema,
    }),
    run: async (args: { slug: string; patch: unknown }) =>
      api.updateMission(args.slug, args.patch),
  },

  mission_report: {
    description:
      "Append a progress report against a mission. host and agent are auto-resolved from $DASH_MCP_HOST/$HOSTNAME and $DASH_MCP_AGENT/$KS_AGENT/$USER unless explicitly overridden.",
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
