import { createDb, type Db } from "@dash-mcp/db/client";
import type { Client } from "@libsql/client";

let cached: { db: Db; client: Client } | null = null;

export function getDb(): { db: Db; client: Client } {
  if (!cached) {
    cached = createDb();
  }
  return cached;
}
