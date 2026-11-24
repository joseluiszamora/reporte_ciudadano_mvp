import { audit, boundedText, lockReport, reportFields, requireProfile, snapshot, writeOptions } from "./domain.js";
import { fail, json } from "./http.js";
import { attachReportPhotos, preparePhotos } from "./media.js";
import { uuidPattern } from "./reports.js";

const transitions = { REPORTED: "IN_FOLLOW_UP", IN_FOLLOW_UP: "REPORTED", RESOLVED: "IN_FOLLOW_UP" };
const identityModes = ["PUBLIC_NAME", "ANONYMOUS"];

async function requireCategory(tx, id) {
  const active = await tx.category.findFirst({
    where: { id, isActive: true }, select: { id: true },
  });
  if (!active) fail(400, "INVALID_CATEGORY");
}

async function findReplay(prisma, id, actor) {
  const existing = await prisma.report.findUnique({
    where: { id }, select: { authorUid: true, deletedAt: true, revision: true },
  });
  if (!existing) return null;
  if (existing.deletedAt || existing.authorUid !== actor.uid) fail(409, "REQUEST_ID_CONFLICT");
  return json({ data: { id, revision: existing.revision } });
}

export async function createReport(prisma, actor, body, files) {
  const id = typeof body.requestId === "string" ? body.requestId.toLowerCase() : "";
  if (!uuidPattern.test(id)) fail(400, "INVALID_REPORT_ID");
  await requireProfile(prisma, actor);
  const replay = await findReplay(prisma, id, actor);
  if (replay) return replay;
  const fields = reportFields(body);
  if (!fields || !identityModes.includes(body.publicIdentityMode)) fail(400, "INVALID_REPORT_CHANGE");
  const photos = await preparePhotos(files);
  try {
    await prisma.$transaction(async (tx) => {
      const publicName = await requireProfile(tx, actor);
      await requireCategory(tx, fields.categoryId);
      await tx.report.create({ data: {
        ...fields, id, authorUid: actor.uid, publicIdentityMode: body.publicIdentityMode,
        publicNameSnapshot: body.publicIdentityMode === "PUBLIC_NAME" ? publicName : null,
      } });
      await attachReportPhotos(tx, id, photos);
      await tx.reportStatusHistory.create({ data: {
        reportId: id, toStatus: "REPORTED", actorUid: actor.uid, note: "Reporte creado",
      } });
      await audit(tx, actor, "REPORT_CREATED", "REPORT", id);
    }, writeOptions);
  } catch (error) {
    if (error.code === "P2002") {
      const concurrent = await findReplay(prisma, id, actor);
      if (concurrent) return concurrent;
    }
    throw error;
  }
  return json({ data: { id, revision: 0 } }, 201);
}

export async function changeReport(prisma, actor, id, body, files = []) {
  if (!uuidPattern.test(id)) fail(400, "INVALID_REPORT_ID");
  const { action, revision } = body;
  const reason = boundedText(body.reason, 10, 1000);
  const edits = action === "edit" ? reportFields(body) : null;
  if (!reason || !Number.isInteger(revision) || revision < 0 || revision >= 2147483647 ||
      !["edit", "status", "delete"].includes(action) || (action === "edit" && !edits) ||
      (action !== "edit" && files.length) ||
      (body.publicIdentityMode !== undefined && !identityModes.includes(body.publicIdentityMode))) {
    fail(400, "INVALID_REPORT_CHANGE");
  }
  if (action === "status" && !actor.admin) fail(403, "ADMIN_REQUIRED");
  // Avoid processing uploads on behalf of a caller who cannot edit the report.
  if (files.length) {
    await requireProfile(prisma, actor);
    const allowed = await prisma.report.findFirst({
      where: { id, deletedAt: null, ...(actor.admin ? {} : { authorUid: actor.uid, status: "REPORTED" }) },
      select: { id: true },
    });
    if (!allowed) fail(404, "NOT_FOUND");
  }
  const photos = await preparePhotos(files, 0);
  const result = await prisma.$transaction(async (tx) => {
    const publicName = await requireProfile(tx, actor);
    const before = await lockReport(tx, id);
    if (!actor.admin && (before.authorUid !== actor.uid ||
        (action === "edit" && before.status !== "REPORTED"))) fail(403, "REPORT_FORBIDDEN");
    if (before.revision !== revision) fail(409, "REPORT_CONFLICT");

    let data;
    let auditAction;
    let changedFields;
    const updatedAt = new Date();
    if (action === "edit") {
      if (before.categoryId !== edits.categoryId) await requireCategory(tx, edits.categoryId);
      if (body.publicIdentityMode !== undefined && before.authorUid === actor.uid &&
          body.publicIdentityMode !== before.publicIdentityMode) {
        edits.publicIdentityMode = body.publicIdentityMode;
        edits.publicNameSnapshot = body.publicIdentityMode === "PUBLIC_NAME" ? publicName : null;
      }
      changedFields = Object.keys(edits).filter((field) => edits[field] !== before[field]);
      if (photos.length) changedFields.push("images");
      if (!changedFields.length) return { revision };
      data = edits;
      auditAction = "REPORT_UPDATED";
      await snapshot(tx, before, actor);
    } else if (action === "status") {
      if (body.status !== transitions[before.status]) fail(400, "INVALID_TRANSITION");
      data = { status: body.status, resolvedAt: null };
      changedFields = before.resolvedAt ? ["status", "resolvedAt"] : ["status"];
      auditAction = "REPORT_STATUS_CHANGED";
    } else {
      data = { deletedAt: updatedAt, deletedByUid: actor.uid, deletionReason: reason };
      changedFields = ["deletedAt"];
      auditAction = "REPORT_DELETED";
    }

    const updated = await tx.report.update({
      where: { id }, data: { ...data, updatedAt, revision: { increment: 1 } },
    });
    if (action === "edit") {
      if (photos.length) {
        await tx.reportImage.deleteMany({ where: { reportId: id } });
        await attachReportPhotos(tx, id, photos);
        await audit(tx, actor, "PHOTO_REPLACED", "REPORT", id, { reason, changedFields: ["images"], isDemo: before.isDemo });
      }
      const images = await tx.reportImage.findMany({ where: { reportId: id }, orderBy: { sortOrder: "asc" } });
      await snapshot(tx, { ...updated, images }, actor);
    }
    if (action === "status") {
      await tx.reportStatusHistory.create({ data: {
        reportId: id, actorUid: actor.uid, fromStatus: before.status, toStatus: body.status,
        note: reason, isDemoAction: before.isDemo,
      } });
    }
    await audit(tx, actor, auditAction, "REPORT", id, { changedFields, reason, isDemo: before.isDemo });
    return { revision: updated.revision };
  }, writeOptions);
  return json({ data: result });
}
