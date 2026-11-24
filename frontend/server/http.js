export class ApiError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
  }
}

export function fail(status, code) {
  throw new ApiError(status, code);
}

export function json(payload, status = 200) {
  return Response.json(payload, { status, headers: { "Cache-Control": "no-store" } });
}

export async function respond(operation) {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof ApiError) return json({ error: error.message }, error.status);
    console.error("Error en la API", error.name, error.code ?? "");
    return json({ error: "INTERNAL_ERROR" }, 500);
  }
}

export async function authenticate(request, verifyToken, admin = false) {
  const bearer = /^Bearer (\S+)$/i.exec(request.headers.get("authorization") ?? "");
  if (!bearer) fail(401, "AUTH_REQUIRED");
  if (!verifyToken) fail(503, "AUTH_UNAVAILABLE");
  let claims;
  try {
    claims = await verifyToken(bearer[1]);
  } catch {
    fail(401, "AUTH_REQUIRED");
  }
  if (typeof claims?.uid !== "string" || !claims.uid) fail(401, "AUTH_REQUIRED");
  if (admin && claims.admin !== true) fail(403, "ADMIN_REQUIRED");
  return { uid: claims.uid, admin: claims.admin === true };
}

async function readLimited(request, maxBytes) {
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > maxBytes) fail(413, "PAYLOAD_TOO_LARGE");
  if (!request.body) fail(400, "INVALID_REQUEST");
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) {
        void reader.cancel().catch(() => {});
        fail(413, "PAYLOAD_TOO_LARGE");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks, size);
}

export async function jsonBody(request) {
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") {
    fail(415, "INVALID_CONTENT_TYPE");
  }
  const bytes = await readLimited(request, 24 * 1024);
  return parseObject(bytes.toString("utf8"));
}

function parseObject(text) {
  try {
    const body = JSON.parse(text);
    if (body && typeof body === "object" && !Array.isArray(body)) return body;
  } catch {
    // Malformed JSON is reported with the same API contract.
  }
  fail(400, "INVALID_REQUEST");
}

export async function photoForm(request, maxPhotos) {
  const type = request.headers.get("content-type") ?? "";
  if (!/^multipart\/form-data\s*;/i.test(type)) fail(415, "INVALID_CONTENT_TYPE");
  const bytes = await readLimited(request, maxPhotos * 10 * 1024 * 1024 + 64 * 1024);
  let form;
  try {
    form = await new Response(bytes, { headers: { "Content-Type": type } }).formData();
  } catch {
    fail(400, "INVALID_REQUEST");
  }
  const metadata = form.getAll("data");
  const photos = form.getAll("photos");
  if (metadata.length !== 1 || typeof metadata[0] !== "string" ||
      Buffer.byteLength(metadata[0]) > 24 * 1024 || photos.length > maxPhotos ||
      photos.some((photo) => typeof photo === "string")) fail(400, "INVALID_REQUEST");
  return { body: parseObject(metadata[0]), photos };
}
