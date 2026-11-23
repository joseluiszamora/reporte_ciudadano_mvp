import { Router } from "express";

export const statuses = ["REPORTED", "IN_FOLLOW_UP", "RESOLVED"];
export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const summaryFields = {
  id: true,
  title: true,
  latitude: true,
  longitude: true,
  status: true,
  publicIdentityMode: true,
  publicNameSnapshot: true,
  createdAt: true,
  resolvedAt: true,
  isDemo: true,
  category: { select: { id: true, name: true, iconKey: true } },
};

const detailFields = {
  ...summaryFields,
  description: true,
  addressLabel: true,
  updatedAt: true,
  revision: true,
  images: {
    orderBy: { sortOrder: "asc" },
    select: { id: true, mimeType: true, sortOrder: true },
  },
  history: {
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    select: { fromStatus: true, toStatus: true, note: true, createdAt: true },
  },
};

function publicReport({ publicNameSnapshot, ...report }) {
  return {
    ...report,
    publicName: report.publicIdentityMode === "ANONYMOUS"
      ? "Ciudadano anónimo"
      : publicNameSnapshot,
  };
}

function utcDate(value) {
  if (typeof value !== "string") return null;
  const parts = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,3}))?Z$/.exec(value);
  if (!parts) return null;
  const date = new Date(value);
  const expected = `${parts[1]}.${(parts[2] ?? "").padEnd(3, "0")}Z`;
  return Number.isFinite(date.getTime()) && date.toISOString() === expected ? date : null;
}

export function createReportsRouter(prisma) {
  const router = Router();

  router.get("/summary", async (req, res) => {
    const { demo = "false" } = req.query;
    if (!["true", "false"].includes(demo)) {
      return res.status(400).json({ error: "INVALID_REPORT_FILTER" });
    }
    const groups = await prisma.report.groupBy({
      by: ["status"],
      where: { deletedAt: null, isDemo: demo === "true" },
      _count: { _all: true },
    });
    const counts = Object.fromEntries(statuses.map((status) => [status, 0]));
    let total = 0;
    for (const group of groups) {
      counts[group.status] = group._count._all;
      total += group._count._all;
    }
    res.json({ data: { total, ...counts } });
  });

  router.get("/", async (req, res) => {
    const {
      q = "", categoryId, status, from, to, order = "desc", demo = "false",
      limit = "20", offset = "0",
    } = req.query;
    const start = utcDate(from);
    const end = utcDate(to);

    if (
      typeof q !== "string" || q.length > 200 || q.includes("\0") ||
      (categoryId !== undefined &&
        (typeof categoryId !== "string" || !/^[a-z0-9-]{1,80}$/.test(categoryId))) ||
      (status !== undefined && !statuses.includes(status)) ||
      (from !== undefined && !start) || (to !== undefined && !end) ||
      (start && end && start >= end) ||
      !["asc", "desc"].includes(order) || !["true", "false"].includes(demo) ||
      typeof limit !== "string" || !/^\d{1,3}$/.test(limit) || +limit < 1 || +limit > 100 ||
      typeof offset !== "string" || !/^\d{1,10}$/.test(offset) || +offset > 2147483547
    ) {
      return res.status(400).json({ error: "INVALID_REPORT_FILTER" });
    }

    const search = q.trim().replace(/[\\%_]/g, "\\$&");
    const where = { deletedAt: null, isDemo: demo === "true", categoryId, status };
    if (start || end) where.createdAt = { gte: start ?? undefined, lt: end ?? undefined };
    if (search) {
      where.OR = [
        { title: { contains: search, mode: "insensitive" } },
        { description: { contains: search, mode: "insensitive" } },
      ];
    }

    const pageSize = Number(limit);
    const skip = Number(offset);
    const reports = await prisma.report.findMany({
      where,
      orderBy: [{ createdAt: order }, { id: order }],
      skip,
      take: pageSize + 1,
      select: summaryFields,
    });
    const nextOffset = reports.length > pageSize ? skip + pageSize : null;

    res.json({ data: reports.slice(0, pageSize).map(publicReport), nextOffset });
  });

  router.get("/:id", async (req, res) => {
    const { id } = req.params;
    if (!uuidPattern.test(id)) return res.status(400).json({ error: "INVALID_REPORT_ID" });

    const report = await prisma.report.findFirst({
      where: { id, deletedAt: null },
      select: detailFields,
    });
    if (!report) return res.status(404).json({ error: "NOT_FOUND" });
    res.json({ data: publicReport(report) });
  });

  return router;
}
