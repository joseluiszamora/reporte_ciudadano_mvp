import { json, Router } from "express";
import { uuidPattern } from "./reports.js";

const nextStatus = {
  REPORTED: "IN_FOLLOW_UP",
  IN_FOLLOW_UP: "REPORTED",
  RESOLVED: "IN_FOLLOW_UP",
};

function boundedText(value, min, max) {
  if (typeof value !== "string" || value.includes("\0")) return null;
  const text = value.trim();
  const length = [...text].length;
  return length >= min && length <= max ? text : null;
}

function editFields(body) {
  const title = boundedText(body.title, 10, 100);
  const description = boundedText(body.description, 20, 2000);
  const addressLabel = body.addressLabel === null ? null : boundedText(body.addressLabel, 1, 250);
  const { latitude, longitude, categoryId } = body;
  if (!title || !description || (body.addressLabel !== null && !addressLabel) ||
      typeof categoryId !== "string" || !/^[a-z0-9-]{1,80}$/.test(categoryId) ||
      !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
      !Number.isFinite(longitude) || Math.abs(longitude) > 180) return null;
  return { title, description, categoryId, latitude, longitude, addressLabel };
}

function writeAudit(prisma, actorUid, action, entityType, entityId, details) {
  return prisma.auditEvent.create({
    data: { actorUid, actorRole: "ADMIN", action, entityType, entityId, ...details },
  });
}

async function snapshot(tx, report, actorUid) {
  const { id, revision } = report;
  await tx.reportRevision.upsert({
    where: { reportId_revision: { reportId: id, revision } },
    create: {
      reportId: id, revision, changedByUid: actorUid,
      snapshot: JSON.parse(JSON.stringify(report)),
    },
    update: {},
  });
}

export function createAdminRouter(prisma, verifyToken) {
  const router = Router();

  router.use(async (req, res, next) => {
    res.set("Cache-Control", "no-store");
    const bearer = /^Bearer (\S+)$/i.exec(req.get("authorization") ?? "");
    if (!bearer) return res.status(401).json({ error: "AUTH_REQUIRED" });
    if (!verifyToken) return res.status(503).json({ error: "AUTH_UNAVAILABLE" });
    let claims;
    try {
      claims = await verifyToken(bearer[1]);
    } catch {
      return res.status(401).json({ error: "AUTH_REQUIRED" });
    }
    if (typeof claims?.uid !== "string" || !claims.uid || claims.admin !== true) {
      return res.status(403).json({ error: "ADMIN_REQUIRED" });
    }
    res.locals.uid = claims.uid;
    next();
  });
  router.use(json({ limit: "24kb" }));

  router.get("/session", async (_req, res) => {
    const user = await prisma.user.findUnique({
      where: { id: res.locals.uid }, select: { publicName: true },
    });
    res.json({ data: { publicName: user?.publicName ?? null } });
  });

  router.put("/profile", async (req, res) => {
    const publicName = boundedText(req.body?.publicName, 2, 50);
    if (!publicName) return res.status(400).json({ error: "INVALID_PROFILE" });
    const id = res.locals.uid;
    await prisma.$transaction(async (tx) => {
      await tx.user.upsert({ where: { id }, create: { id }, update: {} });
      const completed = await tx.user.updateMany({
        where: { id, publicName: null }, data: { publicName },
      });
      const changed = completed.count || (await tx.user.updateMany({
        where: { id, publicName: { not: publicName } }, data: { publicName },
      })).count;
      if (changed) {
        await writeAudit(tx, id, completed.count ? "PROFILE_COMPLETED" : "PROFILE_UPDATED",
          "USER", id, { changedFields: ["public_name"] });
      }
    });
    res.json({ data: { publicName } });
  });

  router.patch("/reports/:id", async (req, res) => {
    const { id } = req.params;
    if (!uuidPattern.test(id)) return res.status(400).json({ error: "INVALID_REPORT_ID" });
    const body = req.body ?? {};
    const { action, revision } = body;
    const reason = boundedText(body.reason, 10, 1000);
    const edits = action === "edit" ? editFields(body) : null;
    if (!reason || !Number.isInteger(revision) || revision < 0 || revision >= 2147483647 ||
        !["edit", "status", "delete"].includes(action) || (action === "edit" && !edits)) {
      return res.status(400).json({ error: "INVALID_REPORT_CHANGE" });
    }

    const uid = res.locals.uid;
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: uid }, select: { publicName: true } });
      if (!user?.publicName) return { status: 403, error: "PROFILE_REQUIRED" };
      const before = await tx.report.findFirst({
        where: { id, deletedAt: null }, include: action === "edit" ? { images: true } : undefined,
      });
      if (!before) return { status: 404, error: "NOT_FOUND" };
      if (before.revision !== revision) return { status: 409, error: "REPORT_CONFLICT" };

      let data;
      let auditAction;
      let changedFields;
      const updatedAt = new Date();
      if (action === "edit") {
        if (before.categoryId !== edits.categoryId && !await tx.category.findFirst({
          where: { id: edits.categoryId, isActive: true }, select: { id: true },
        })) return { status: 400, error: "INVALID_CATEGORY" };
        changedFields = Object.keys(edits).filter((field) => edits[field] !== before[field]);
        if (changedFields.length === 0) return { revision };
        data = edits;
        auditAction = "REPORT_UPDATED";
      } else if (action === "status") {
        if (body.status !== nextStatus[before.status]) {
          return { status: 400, error: "INVALID_TRANSITION" };
        }
        data = { status: body.status, resolvedAt: null };
        changedFields = before.resolvedAt ? ["status", "resolvedAt"] : ["status"];
        auditAction = "REPORT_STATUS_CHANGED";
      } else {
        data = { deletedAt: updatedAt, deletedByUid: uid, deletionReason: reason };
        changedFields = ["deletedAt"];
        auditAction = "REPORT_DELETED";
      }

      const updated = await tx.report.updateMany({
        where: { id, revision, deletedAt: null }, data: { ...data, updatedAt, revision: { increment: 1 } },
      });
      if (!updated.count) return { status: 409, error: "REPORT_CONFLICT" };

      if (action === "edit") {
        await snapshot(tx, before, uid);
        await snapshot(tx, { ...before, ...edits, revision: revision + 1, updatedAt }, uid);
      }
      if (action === "status") {
        await tx.reportStatusHistory.create({
          data: {
            reportId: id, actorUid: uid, fromStatus: before.status, toStatus: body.status,
            note: reason, isDemoAction: before.isDemo,
          },
        });
      }
      await writeAudit(tx, uid, auditAction, "REPORT", id, { changedFields, reason, isDemo: before.isDemo });
      return { revision: revision + 1 };
    });
    if (result.error) return res.status(result.status).json({ error: result.error });
    res.json({ data: result });
  });

  return router;
}
