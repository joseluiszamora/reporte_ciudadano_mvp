import express from "express";
import { createAdminRouter } from "./admin.js";
import { createReportsRouter } from "./reports.js";

export function createApp(prisma, { verifyToken } = {}) {
  const app = express();
  app.disable("x-powered-by");

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.get("/ready", async (_req, res) => {
    res.set("Cache-Control", "no-store");
    try {
      await prisma.$queryRaw`SELECT 1`;
      res.json({ status: "ok" });
    } catch {
      res.status(503).json({ status: "unavailable" });
    }
  });

  app.get("/api/v1/categories", async (_req, res) => {
    const categories = await prisma.category.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
      select: { id: true, slug: true, name: true, iconKey: true, sortOrder: true },
    });
    res.json({ data: categories });
  });

  app.use("/api/v1/reports", createReportsRouter(prisma));
  app.use("/api/v1/admin", createAdminRouter(prisma, verifyToken));

  app.use((_req, res) => {
    res.status(404).json({ error: "NOT_FOUND" });
  });

  app.use((error, _req, res, next) => {
    if (res.headersSent) return next(error);
    if (error instanceof URIError) {
      return res.status(400).json({ error: "INVALID_REQUEST" });
    }
    if (error.type === "entity.parse.failed" || error.type === "entity.too.large") {
      return res.status(error.status).json({ error: "INVALID_REQUEST" });
    }
    console.error("Error al procesar la solicitud:", error.name, error.code ?? "");
    res.status(500).json({ error: "INTERNAL_ERROR" });
  });

  return app;
}
