import { error, json } from "./http.js";
import {
  createMission,
  getMissionBySlug,
  listMissions,
  updateMission,
} from "./routes/missions.js";
import { createReport } from "./routes/reports.js";
import { listAgents, listHosts } from "./routes/fleet.js";

const port = Number(process.env.PORT ?? 7878);

const server = Bun.serve({
  port,
  hostname: "127.0.0.1",
  async fetch(req) {
    const url = new URL(req.url);
    const { pathname } = url;
    const method = req.method.toUpperCase();

    if (method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET,POST,PATCH,DELETE,OPTIONS",
          "access-control-allow-headers": "content-type",
        },
      });
    }

    if (pathname === "/healthz") return json({ ok: true });

    if (pathname === "/api/missions" && method === "GET") return listMissions(url);
    if (pathname === "/api/missions" && method === "POST") return createMission(req);

    const missionMatch = pathname.match(/^\/api\/missions\/([^/]+)$/);
    if (missionMatch) {
      const slug = decodeURIComponent(missionMatch[1]!);
      if (method === "GET") return getMissionBySlug(slug);
      if (method === "PATCH") return updateMission(slug, req);
    }

    const reportMatch = pathname.match(/^\/api\/missions\/([^/]+)\/reports$/);
    if (reportMatch && method === "POST") {
      const slug = decodeURIComponent(reportMatch[1]!);
      return createReport(slug, req);
    }

    if (pathname === "/api/hosts" && method === "GET") return listHosts();
    if (pathname === "/api/agents" && method === "GET") return listAgents();

    return error("not_found", `no route for ${method} ${pathname}`, 404);
  },
});

console.error(`[dash-mcp/server] listening on http://${server.hostname}:${server.port}`);
