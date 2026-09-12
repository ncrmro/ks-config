import { defineConfig } from "drizzle-kit";

const url = process.env.DATABASE_URL ?? "http://127.0.0.1:8080";

export default defineConfig({
  schema: "./src/schema.ts",
  out: "./migrations",
  dialect: "turso",
  dbCredentials: { url },
  strict: true,
  verbose: true,
});
