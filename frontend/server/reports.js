import { fail, json } from "./http.js";

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
    select: { id: true, mimeType: true, sortOrder: true, storageKey: true },
  },
  history: {
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    select: { fromStatus: true, toStatus: true, note: true, createdAt: true },
  },
  proposals: {
    where: { status: "APPROVED" },
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    select: { id: true, note: true, createdAt: true, reviewedAt: true, evidenceStorageKey: true },
  },
};

export function publicReport({ publicNameSnapshot, ...report }) {
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

export async function categories(prisma) {
  return json({ data: await prisma.category.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
    select: { id: true, slug: true, name: true, iconKey: true, sortOrder: true },
  }) });
}

export async function summary(prisma, params) {
  const demo = params.get("demo") ?? "false";
  if (params.getAll("demo").length > 1 || !["true", "false"].includes(demo)) fail(400, "INVALID_REPORT_FILTER");
  const groups = await prisma.report.groupBy({
    by: ["status"], where: { deletedAt: null, isDemo: demo === "true" }, _count: { _all: true },
  });
  const counts = Object.fromEntries(statuses.map((status) => [status, 0]));
  let total = 0;
  for (const group of groups) {
    counts[group.status] = group._count._all;
    total += group._count._all;
  }
  return json({ data: { total, ...counts } });
}

export async function listReports(prisma, params, authorUid) {
  const keys = ["q", "categoryId", "status", "from", "to", "order", "demo", "limit", "offset"];
  if (keys.some((key) => params.getAll(key).length > 1)) fail(400, "INVALID_REPORT_FILTER");
  const {
    q = "", categoryId, status, from, to, order = "desc", demo = "false", limit = "20", offset = "0",
  } = Object.fromEntries(params);
  const start = utcDate(from);
  const end = utcDate(to);
  if (
    q.length > 200 || q.includes("\0") ||
    (categoryId !== undefined && !/^[a-z0-9-]{1,80}$/.test(categoryId)) ||
    (status !== undefined && !statuses.includes(status)) ||
    (from !== undefined && !start) || (to !== undefined && !end) ||
    (start && end && start >= end) ||
    !["asc", "desc"].includes(order) || !["true", "false"].includes(demo) ||
    !/^\d{1,3}$/.test(limit) || +limit < 1 || +limit > 100 ||
    !/^\d{1,10}$/.test(offset) || +offset > 2147483547
  ) fail(400, "INVALID_REPORT_FILTER");

  const search = q.trim().replace(/[\\%_]/g, "\\$&");
  const where = { deletedAt: null, isDemo: demo === "true", categoryId, status, authorUid };
  if (start || end) where.createdAt = { gte: start ?? undefined, lt: end ?? undefined };
  if (search) {
    where.OR = [
      { title: { contains: search, mode: "insensitive" } },
      { description: { contains: search, mode: "insensitive" } },
    ];
  }
  const take = Number(limit);
  const skip = Number(offset);
  const reports = await prisma.report.findMany({
    where, orderBy: [{ createdAt: order }, { id: order }], skip, take: take + 1, select: summaryFields,
  });
  return json({ data: reports.slice(0, take).map(publicReport), nextOffset: reports.length > take ? skip + take : null });
}

export function mediaUrl(id) {
  return uuidPattern.test(id) ? "/api/v1/media/" + id : null;
}

export async function reportDetail(prisma, id) {
  if (!uuidPattern.test(id)) fail(400, "INVALID_REPORT_ID");
  const report = await prisma.report.findFirst({ where: { id, deletedAt: null }, select: detailFields });
  if (!report) fail(404, "NOT_FOUND");
  report.images = report.images.map(({ storageKey, ...image }) => ({ ...image, url: mediaUrl(storageKey) }));
  report.proposals = report.proposals.map(({ evidenceStorageKey, ...proposal }) => ({
    ...proposal, evidenceUrl: mediaUrl(evidenceStorageKey),
  }));
  return json({ data: publicReport(report) });
}
