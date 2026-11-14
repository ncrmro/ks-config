import { createClient, type Client } from "@libsql/client";
import { drizzle, type LibSQLDatabase } from "drizzle-orm/libsql";
import * as schema from "./schema.js";

export type Db = LibSQLDatabase<typeof schema>;

export function createDb(url: string = requireUrl()): {
  db: Db;
  client: Client;
} {
  const client = createClient({ url });
  const db = drizzle(client, { schema });
  return { db, client };
}

function requireUrl(): string {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error(
      "DATABASE_URL is not set. Expected something like http://127.0.0.1:<sqld-port>",
    );
  }
  return url;
}
