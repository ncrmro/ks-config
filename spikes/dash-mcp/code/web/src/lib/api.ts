const baseUrl =
  import.meta.env.PUBLIC_SERVER_URL ??
  process.env.PUBLIC_SERVER_URL ??
  "http://127.0.0.1:7878";

export type Mission = {
  id: number;
  slug: string;
  project: string;
  title: string;
  purpose: string;
  status: "proposed" | "active" | "blocked" | "done" | "archived";
  ownerAgent: string | null;
  createdAt: string;
  updatedAt: string;
};

export type Report = {
  id: number;
  kind: "work_started" | "work_update" | "blocked" | "done" | "note";
  summary: string;
  refs: string[];
  createdAt: string;
  host: string;
  agent: string;
};

export type Milestone = {
  id: number;
  title: string;
  dueAt: string | null;
  status: "planned" | "in_progress" | "blocked" | "done" | "cancelled";
};

export type Repo = {
  id: number;
  ref: string;
  url: string;
  label: string | null;
};

export type MissionDetail = {
  mission: Mission;
  values: string[];
  scopeIn: string[];
  scopeOut: string[];
  milestones: Milestone[];
  repos: Repo[];
  reports: Report[];
};

export type Host = {
  id: number;
  hostname: string;
  firstSeen: string;
  lastSeen: string;
};

export type Agent = {
  id: number;
  name: string;
  host: string;
  firstSeen: string;
  lastSeen: string;
};

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${baseUrl}${path}`);
  if (!res.ok) throw new Error(`GET ${path} -> HTTP ${res.status}`);
  return (await res.json()) as T;
}

export const api = {
  listMissions: () => get<{ missions: Mission[] }>("/api/missions"),
  getMission: (slug: string) =>
    get<MissionDetail>(`/api/missions/${encodeURIComponent(slug)}`),
  listHosts: () => get<{ hosts: Host[] }>("/api/hosts"),
  listAgents: () => get<{ agents: Agent[] }>("/api/agents"),
};

export { baseUrl };
