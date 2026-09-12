import { ZodError, type ZodSchema } from "zod";

export function json(data: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      ...(init.headers ?? {}),
    },
  });
}

export function error(
  code: string,
  message: string,
  status = 400,
): Response {
  return json({ error: { code, message } }, { status });
}

export async function parseJson<T>(
  req: Request,
  schema: ZodSchema<T>,
): Promise<{ ok: true; data: T } | { ok: false; response: Response }> {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return { ok: false, response: error("invalid_json", "request body is not valid JSON") };
  }
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    return {
      ok: false,
      response: error("validation_failed", formatZod(parsed.error), 422),
    };
  }
  return { ok: true, data: parsed.data };
}

export function parseQuery<T>(
  url: URL,
  schema: ZodSchema<T>,
): { ok: true; data: T } | { ok: false; response: Response } {
  const obj: Record<string, string> = {};
  for (const [k, v] of url.searchParams.entries()) obj[k] = v;
  const parsed = schema.safeParse(obj);
  if (!parsed.success) {
    return {
      ok: false,
      response: error("invalid_query", formatZod(parsed.error), 422),
    };
  }
  return { ok: true, data: parsed.data };
}

function formatZod(err: ZodError): string {
  return err.issues
    .map((i) => `${i.path.join(".") || "<root>"}: ${i.message}`)
    .join("; ");
}
