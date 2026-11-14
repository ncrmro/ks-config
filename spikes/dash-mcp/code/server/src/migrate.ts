import { migrate } from "drizzle-orm/libsql/migrator";
import { getDb } from "./db.js";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const migrationsFolder = resolve(here, "../../db/migrations");

async function main() {
  const { db, client } = getDb();
  console.error(`[migrate] applying migrations from ${migrationsFolder}`);
  await migrate(db, { migrationsFolder });
  console.error("[migrate] done");
  client.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
