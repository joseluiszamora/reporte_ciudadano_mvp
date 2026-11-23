const publicRoute = /^(categories|reports(?:\/(?:summary|[a-z0-9-]+))?)$/i;
const adminReport = /^admin\/reports\/[a-z0-9-]+$/i;

async function proxy(request, { params }) {
  const { segments } = await params;
  const path = segments.join("/");
  const { method } = request;
  const allowed = (method === "GET" && (publicRoute.test(path) || path === "admin/session")) ||
    (method === "PUT" && path === "admin/profile") ||
    (method === "PATCH" && adminReport.test(path));
  if (!allowed) return Response.json({ error: "NOT_FOUND" }, { status: 404 });

  const headers = new Headers({ Accept: "application/json" });
  for (const key of ["authorization", "content-type"]) {
    const value = request.headers.get(key);
    if (value) headers.set(key, value);
  }
  try {
    const api = new URL("/api/v1/" + path, process.env.REPORTS_API_URL ?? "http://127.0.0.1:3000");
    api.search = new URL(request.url).search;
    const response = await fetch(api, {
      method, headers, cache: "no-store", redirect: "error",
      signal: AbortSignal.timeout(8000),
      ...(method !== "GET" && { body: request.body, duplex: "half" }),
    });
    return new Response(response.body, {
      status: response.status,
      headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    });
  } catch {
    return Response.json({ error: "API_UNAVAILABLE" }, { status: 502 });
  }
}

export const GET = proxy;
export const PATCH = proxy;
export const PUT = proxy;
