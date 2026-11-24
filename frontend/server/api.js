import { authenticate, fail, json, jsonBody, photoForm, respond } from "./http.js";
import { serveMedia } from "./media.js";
import { readProfile, saveProfile } from "./profile.js";
import { createProposal, listProposals, reviewProposal } from "./proposals.js";
import { changeReport, createReport } from "./report-writes.js";
import { categories, listReports, reportDetail, summary } from "./reports.js";

export function serveApi(prisma, verifyToken, request, segments) {
  return respond(async () => {
    const path = segments.join("/");
    const method = request.method === "HEAD" ? "GET" : request.method;
    const params = new URL(request.url).searchParams;
    const adminRoute = segments[0] === "admin";
    const actor = () => authenticate(request, verifyToken, adminRoute);

    if (method === "GET" && path === "health") return json({ status: "ok" });
    if (method === "GET" && path === "ready") {
      try {
        await prisma.$queryRaw`SELECT 1`;
        return json({ status: "ok" });
      } catch {
        return json({ status: "unavailable" }, 503);
      }
    }
    if (method === "GET" && path === "categories") return categories(prisma);
    if (method === "GET" && path === "reports") return listReports(prisma, params);
    if (method === "GET" && path === "reports/summary") return summary(prisma, params);
    if (method === "GET" && path === "me/reports") {
      return listReports(prisma, params, (await actor()).uid);
    }
    if (method === "GET" && ["me", "admin/session"].includes(path)) {
      return readProfile(prisma, await actor(), adminRoute);
    }
    if (method === "PUT" && ["me/profile", "admin/profile"].includes(path)) {
      return saveProfile(prisma, await actor(), await jsonBody(request));
    }
    if (method === "POST" && path === "reports") {
      const citizen = await actor();
      const { body, photos } = await photoForm(request, 5);
      return createReport(prisma, citizen, body, photos);
    }
    if (method === "GET" && segments.length === 2 && segments[0] === "media") {
      const viewer = request.headers.has("authorization") ? await actor() : undefined;
      return serveMedia(prisma, segments[1], viewer);
    }
    if (method === "GET" && segments.length === 2 && segments[0] === "reports") {
      return reportDetail(prisma, segments[1]);
    }
    const reportId = adminRoute && segments.length === 3 && segments[1] === "reports"
      ? segments[2] : segments.length === 2 && segments[0] === "reports" ? segments[1] : null;
    if (reportId && method === "PATCH") {
      const editor = await actor();
      const payload = /^multipart\/form-data\s*;/i.test(request.headers.get("content-type") ?? "")
        ? await photoForm(request, 5) : { body: await jsonBody(request), photos: [] };
      return changeReport(prisma, editor, reportId, payload.body, payload.photos);
    }
    if (segments.length === 3 && segments[0] === "reports" && segments[2] === "proposals") {
      if (method === "GET") return listProposals(prisma, await actor(), segments[1]);
      if (method === "POST") {
        const citizen = await actor();
        const { body, photos } = await photoForm(request, 1);
        return createProposal(prisma, citizen, segments[1], body, photos);
      }
    }
    if (method === "PATCH" && adminRoute && segments.length === 3 && segments[1] === "proposals") {
      return reviewProposal(prisma, await actor(), segments[2], await jsonBody(request));
    }
    fail(404, "NOT_FOUND");
  });
}
