import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import test from "node:test";
import sharp from "sharp";
import { serveApi } from "./api.js";
import { getPrisma } from "./services.js";

test("la API móvil conserva permisos, fotos, auditoría e idempotencia", {
  skip: !process.env.DATABASE_URL,
}, async () => {
  const prisma = getPrisma();
  const reportId = randomUUID();
  const proposalId = randomUUID();
  const users = {
    citizen: { uid: "test-author-" + reportId, admin: false },
    other: { uid: "test-other-" + reportId, admin: false },
    admin: { uid: "test-admin-" + reportId, admin: true },
  };
  const fixture = await sharp({
    create: { width: 3, height: 3, channels: 3, background: "red" },
  }).png().toBuffer();
  const rollback = new Error("Revertir datos de prueba");

  try {
    await assert.rejects(prisma.$transaction(async (tx) => {
      const db = {
        $transaction: (operation) => operation(tx),
        $queryRaw: tx.$queryRaw.bind(tx),
        category: tx.category,
        mediaAsset: tx.mediaAsset,
        report: tx.report,
        reportImage: tx.reportImage,
        resolutionProposal: tx.resolutionProposal,
        user: tx.user,
      };
      async function call(path, { token, method = "GET", body, photo, expected = 200 } = {}) {
        const url = new URL(path, "http://localhost/api/v1/");
        const headers = token ? { Authorization: "Bearer " + token } : {};
        let payload;
        if (photo) {
          payload = new FormData();
          payload.set("data", JSON.stringify(body));
          payload.append("photos", new Blob([photo]), "evidencia.png");
        } else if (body) {
          headers["Content-Type"] = "application/json";
          payload = JSON.stringify(body);
        }
        const request = new Request(url, { method, headers, body: payload });
        const response = await serveApi(db, async (key) => users[key], request, url.pathname.split("/").slice(3));
        assert.equal(response.status, expected, expected === response.status ? path : await response.clone().text());
        return response.headers.get("content-type").startsWith("image/")
          ? new Uint8Array(await response.arrayBuffer()) : (await response.json()).data;
      }

      const draft = {
        requestId: reportId, categoryId: "baches", title: "Bache crítico frente a la plaza",
        description: "La vía presenta un bache cerca del cruce principal.",
        latitude: -16.5, longitude: -68.15, publicIdentityMode: "ANONYMOUS",
      };
      const reason = "Motivo de la prueba de integración";
      assert.equal((await call("categories")).length, 8);
      await call("reports", { method: "POST", body: draft, photo: fixture, expected: 401 });
      await call("reports", { method: "POST", token: "citizen", body: draft, photo: fixture, expected: 403 });
      for (const token of Object.keys(users)) {
        await call("me/profile", { method: "PUT", token, body: { publicName: "Perfil de prueba" } });
      }
      await call("reports", { method: "POST", token: "citizen", body: draft, photo: new Uint8Array([1]), expected: 400 });
      const created = await call("reports", { method: "POST", token: "citizen", body: draft, photo: fixture, expected: 201 });
      assert.equal(created.id, reportId);
      assert.equal((await call("reports", { method: "POST", token: "citizen", body: draft, photo: fixture })).id, reportId);
      await call("reports", { method: "POST", token: "other", body: draft, photo: fixture, expected: 409 });
      const detailPath = "reports/" + reportId;
      const detail = await call(detailPath);
      assert.equal(detail.publicName, "Ciudadano anónimo");
      assert.ok(!JSON.stringify(detail).includes(users.citizen.uid));
      const photoPath = detail.images[0].url.replace("/api/v1/", "");
      assert.deepEqual([...(await call(photoPath)).slice(0, 2)], [255, 216]);
      const filtered = await call("me/reports?q=CR%C3%8DTICO", { token: "citizen" });
      assert.ok(filtered.some(({ id }) => id === reportId));
      await call(detailPath, { method: "PATCH", token: "other", body: { action: "delete", revision: 0, reason }, expected: 403 });
      await call(detailPath, { method: "PATCH", token: "citizen", body: { ...draft, action: "edit", revision: 0, title: "Bache junto a la plaza", reason } });
      await call(detailPath, { method: "PATCH", token: "citizen", body: { action: "delete", revision: 0, reason }, expected: 409 });

      const proposals = detailPath + "/proposals";
      const evidence = { requestId: proposalId, note: "Se reparó el bache de esta vía." };
      await call(proposals, { method: "POST", token: "citizen", body: evidence, photo: fixture, expected: 201 });
      assert.equal((await call(proposals, { method: "POST", token: "citizen", body: evidence, photo: fixture })).id, proposalId);
      assert.equal((await call(proposals, { token: "other" })).length, 0);
      const evidencePath = (await call(proposals, { token: "admin" }))[0].evidenceUrl.replace("/api/v1/", "");
      await call(evidencePath, { expected: 404 });
      await call(evidencePath, { token: "admin" });
      const reviewPath = "admin/proposals/" + proposalId;
      const review = { action: "approve", reason };
      await call(reviewPath, { method: "PATCH", token: "citizen", body: review, expected: 403 });
      await call(reviewPath, { method: "PATCH", token: "admin", body: review });
      assert.equal((await call(detailPath)).status, "RESOLVED");
      await call(evidencePath);
      await call("admin/" + detailPath, { method: "PATCH", token: "admin",
        body: { action: "status", revision: 2, status: "IN_FOLLOW_UP", reason } });
      await call(detailPath, { method: "PATCH", token: "citizen", body: { action: "delete", revision: 3, reason } });
      await call(detailPath, { expected: 404 });
      await call(photoPath, { expected: 404 });
      assert.equal(await tx.auditEvent.count({ where: { entityId: proposalId } }), 2);
      assert.equal(await tx.reportRevision.count({ where: { reportId } }), 2);
      throw rollback;
    }, { timeout: 60_000 }), (error) => error === rollback);
    assert.equal(await prisma.report.findUnique({ where: { id: reportId } }), null);
    assert.equal(await prisma.user.findUnique({ where: { id: users.admin.uid } }), null);
  } finally {
    await prisma.$disconnect();
  }
});
