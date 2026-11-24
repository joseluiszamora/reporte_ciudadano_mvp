import { fail } from "./http.js";

export function boundedText(value, min, max) {
  if (typeof value !== "string" || value.includes("\0")) return null;
  const text = value.trim();
  const length = [...text].length;
  return length >= min && length <= max ? text : null;
}

export function reportFields(body) {
  const title = boundedText(body.title, 10, 100);
  const description = boundedText(body.description, 20, 2000);
  const addressLabel = body.addressLabel == null ? null : boundedText(body.addressLabel, 1, 250);
  const { latitude, longitude, categoryId } = body;
  if (!title || !description || (body.addressLabel != null && !addressLabel) ||
      typeof categoryId !== "string" || !/^[a-z0-9-]{1,80}$/.test(categoryId) ||
      !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
      !Number.isFinite(longitude) || Math.abs(longitude) > 180) return null;
  return { title, description, categoryId, latitude, longitude, addressLabel };
}

export function audit(tx, actor, action, entityType, entityId, details = {}) {
  return tx.auditEvent.create({ data: {
    actorUid: actor.uid, actorRole: actor.admin ? "ADMIN" : "CITIZEN", action, entityType, entityId, ...details,
  } });
}

export async function requireProfile(tx, actor) {
  const user = await tx.user.findUnique({ where: { id: actor.uid }, select: { publicName: true } });
  if (!user?.publicName) fail(403, "PROFILE_REQUIRED");
  return user.publicName;
}

export async function lockReport(tx, id) {
  const rows = await tx.$queryRaw`SELECT id FROM reports WHERE id = ${id}::uuid AND deleted_at IS NULL FOR UPDATE`;
  if (!rows.length) fail(404, "NOT_FOUND");
  return tx.report.findUniqueOrThrow({ where: { id }, include: { images: { orderBy: { sortOrder: "asc" } } } });
}

export function snapshot(tx, report, actor) {
  const { id, revision } = report;
  return tx.reportRevision.upsert({
    where: { reportId_revision: { reportId: id, revision } },
    update: {},
    create: { reportId: id, revision, changedByUid: actor.uid, snapshot: JSON.parse(JSON.stringify(report)) },
  });
}

export const writeOptions = { timeout: 30_000 };
