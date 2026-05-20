// Re-export the zod schemas generated from the drizzle tables. Keeping a thin
// shim here so route files don't need to know whether the canonical source
// lives in @dash-mcp/db (today) or some future location.
export {
  createMissionInputSchema as createMissionSchema,
  updateMissionInputSchema as updateMissionSchema,
  createReportInputSchema as createReportSchema,
  listMissionsQuerySchema,
  type CreateMissionInput,
  type UpdateMissionInput,
  type CreateReportInput,
} from "@dash-mcp/db/zod";
