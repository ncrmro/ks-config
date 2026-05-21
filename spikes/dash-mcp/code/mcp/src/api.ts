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
  listProjects: (q: { status?: string } = {}) => {
    const params = new URLSearchParams();
    if (q.status) params.set("status", q.status);
    const qs = params.toString();
    return call("GET", `/api/projects${qs ? `?${qs}` : ""}`);
  },
  getProject: (slug: string) => call("GET", `/api/projects/${encodeURIComponent(slug)}`),
  createProject: (body: unknown) => call("POST", `/api/projects`, body),
  updateProject: (slug: string, patch: unknown) =>
    call("PATCH", `/api/projects/${encodeURIComponent(slug)}`, patch),
  createReport: (slug: string, body: unknown) =>
    call("POST", `/api/projects/${encodeURIComponent(slug)}/reports`, body),
};
