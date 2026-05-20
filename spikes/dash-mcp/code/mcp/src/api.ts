import { serverUrl } from "./identity.js";

async function call(method: string, path: string, body?: unknown): Promise<unknown> {
  const res = await fetch(`${serverUrl()}${path}`, {
    method,
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const msg =
      (data && typeof data === "object" && "error" in data
        ? JSON.stringify(data.error)
        : null) ?? `HTTP ${res.status}`;
    throw new Error(`dash-mcp server: ${msg}`);
  }
  return data;
}

export const api = {
  listMissions: (q: { project?: string; status?: string } = {}) => {
    const params = new URLSearchParams();
    if (q.project) params.set("project", q.project);
    if (q.status) params.set("status", q.status);
    const qs = params.toString();
    return call("GET", `/api/missions${qs ? `?${qs}` : ""}`);
  },
  getMission: (slug: string) => call("GET", `/api/missions/${encodeURIComponent(slug)}`),
  createMission: (body: unknown) => call("POST", `/api/missions`, body),
  updateMission: (slug: string, patch: unknown) =>
    call("PATCH", `/api/missions/${encodeURIComponent(slug)}`, patch),
  createReport: (slug: string, body: unknown) =>
    call("POST", `/api/missions/${encodeURIComponent(slug)}/reports`, body),
};
