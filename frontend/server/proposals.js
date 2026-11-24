import { audit, boundedText, lockReport, requireProfile, writeOptions } from "./domain.js";
import { fail, json } from "./http.js";
import { preparePhotos } from "./media.js";
import { mediaUrl, uuidPattern } from "./reports.js";

const fields = {
  id: true, note: true, status: true, createdAt: true, reviewedAt: true, reviewNote: true,
  evidenceStorageKey: true,
};

export function presentProposal({ evidenceStorageKey, ...proposal }) {
  return { ...proposal, evidenceUrl: mediaUrl(evidenceStorageKey) };
}

export async function listProposals(prisma, actor, reportId) {
  if (!uuidPattern.test(reportId)) fail(400, "INVALID_REPORT_ID");
  const report = await prisma.report.findFirst({
    where: { id: reportId, deletedAt: null },
    select: {
      proposals: {
        where: actor.admin ? undefined : { proposerUid: actor.uid },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }], select: fields,
      },
    },
  });
  if (!report) fail(404, "NOT_FOUND");
  return json({ data: report.proposals.map(presentProposal) });
}

function checkReplay(existing, reportId, actor) {
  if (!existing) return null;
  if (existing.reportId !== reportId || existing.proposerUid !== actor.uid) fail(409, "REQUEST_ID_CONFLICT");
  return json({ data: { id: existing.id, status: existing.status } });
}

export async function createProposal(prisma, actor, reportId, body, files) {
  if (!uuidPattern.test(reportId)) fail(400, "INVALID_REPORT_ID");
  reportId = reportId.toLowerCase();
  const id = typeof body.requestId === "string" ? body.requestId.toLowerCase() : "";
  const note = boundedText(body.note, 10, 1000);
  if (!uuidPattern.test(id) || !note) fail(400, "INVALID_PROPOSAL");
  await requireProfile(prisma, actor);
  const [photo] = await preparePhotos(files);
  try {
    return await prisma.$transaction(async (tx) => {
      const report = await lockReport(tx, reportId);
      const replay = checkReplay(await tx.resolutionProposal.findUnique({ where: { id } }), reportId, actor);
      if (replay) return replay;
      if (report.status === "RESOLVED") fail(409, "REPORT_RESOLVED");
      const pending = await tx.resolutionProposal.findFirst({
        where: { reportId, proposerUid: actor.uid, status: "PENDING" }, select: { id: true },
      });
      if (pending) fail(409, "PROPOSAL_PENDING");
      await tx.mediaAsset.create({ data: photo });
      await tx.resolutionProposal.create({ data: {
        id, reportId, proposerUid: actor.uid, note, evidenceStorageKey: photo.id,
      } });
      await audit(tx, actor, "PROPOSAL_CREATED", "PROPOSAL", id, { isDemo: report.isDemo });
      return json({ data: { id, status: "PENDING" } }, 201);
    }, writeOptions);
  } catch (error) {
    if (error.code === "P2002") {
      const replay = checkReplay(await prisma.resolutionProposal.findUnique({
        where: { id }, include: { report: { select: { deletedAt: true } } },
      }).then((row) => row?.report.deletedAt ? null : row), reportId, actor);
      if (replay) return replay;
    }
    throw error;
  }
}

async function review(tx, actor, id, status, reason, report, now) {
  await tx.resolutionProposal.update({ where: { id }, data: {
    status, reviewedAt: now, reviewerUid: actor.uid, reviewNote: reason, isDemoReview: report.isDemo,
  } });
  await audit(tx, actor, status === "APPROVED" ? "PROPOSAL_APPROVED" : "PROPOSAL_REJECTED",
    "PROPOSAL", id, { reason, changedFields: ["status"], isDemo: report.isDemo });
}

export async function reviewProposal(prisma, actor, id, body) {
  if (!uuidPattern.test(id)) fail(400, "INVALID_PROPOSAL");
  const reason = boundedText(body.reason, 10, 1000);
  if (!reason || !["approve", "reject"].includes(body.action)) fail(400, "INVALID_PROPOSAL");
  const status = body.action === "approve" ? "APPROVED" : "REJECTED";
  await prisma.$transaction(async (tx) => {
    await requireProfile(tx, actor);
    const reference = await tx.resolutionProposal.findUnique({ where: { id }, select: { reportId: true } });
    if (!reference) fail(404, "NOT_FOUND");
    const report = await lockReport(tx, reference.reportId);
    const proposal = await tx.resolutionProposal.findUniqueOrThrow({ where: { id } });
    if (proposal.status !== "PENDING" || report.status === "RESOLVED") fail(409, "PROPOSAL_CONFLICT");
    const now = new Date(Math.max(Date.now(), report.createdAt.getTime()));
    await review(tx, actor, proposal.id, status, reason, report, now);
    if (status === "REJECTED") return;
    const remaining = await tx.resolutionProposal.findMany({
      where: { reportId: report.id, status: "PENDING" }, select: { id: true },
    });
    for (const item of remaining) await review(tx, actor, item.id, "REJECTED", "Sustituida por propuesta aprobada", report, now);
    await tx.report.update({ where: { id: report.id }, data: {
      status: "RESOLVED", resolvedAt: now, revision: { increment: 1 },
    } });
    await tx.reportStatusHistory.create({ data: {
      reportId: report.id, proposalId: proposal.id, actorUid: actor.uid, fromStatus: report.status,
      toStatus: "RESOLVED", note: reason, isDemoAction: report.isDemo,
    } });
    await audit(tx, actor, "REPORT_STATUS_CHANGED", "REPORT", report.id, {
      reason, changedFields: ["status", "resolvedAt"], isDemo: report.isDemo,
    });
  }, writeOptions);
  return json({ data: { id, status } });
}
