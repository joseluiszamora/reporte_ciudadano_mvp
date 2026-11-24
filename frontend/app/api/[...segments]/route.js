import { serveApi } from "../../../server/api.js";
import { json, respond } from "../../../server/http.js";
import { getPrisma, getVerifier } from "../../../server/services.js";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function handle(request, { params }) {
  const { segments } = await params;
  const path = segments[0] === "v1" ? segments.slice(1) : segments;
  if (request.method === "GET" && path.join("/") === "health") {
    return json({ status: "ok" });
  }
  if (request.method === "GET" && path.join("/") === "ready" && !process.env.DATABASE_URL) {
    return json({ status: "unavailable" }, 503);
  }
  return respond(() => serveApi(getPrisma(), getVerifier(), request, path));
}

export const GET = handle;
export const PUT = handle;
export const POST = handle;
export const PATCH = handle;
