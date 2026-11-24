import { randomUUID } from "node:crypto";
import sharp from "sharp";
import { fail } from "./http.js";
import { uuidPattern } from "./reports.js";

export async function preparePhotos(files, min = 1) {
  if (files.length < min) fail(400, "INVALID_PHOTO_COUNT");
  const images = [];
  for (const file of files) {
    if (file.size < 1 || file.size > 10 * 1024 * 1024) fail(400, "INVALID_PHOTO");
    try {
      const image = sharp(Buffer.from(await file.arrayBuffer()), { limitInputPixels: 20_000_000 });
      const metadata = await image.metadata();
      if (!["jpeg", "png", "webp"].includes(metadata.format) || (metadata.pages ?? 1) !== 1) {
        fail(400, "INVALID_PHOTO");
      }
      const bytes = await image.autoOrient()
        .resize({ width: 2048, height: 2048, fit: "inside", withoutEnlargement: true })
        .jpeg({ quality: 85 }).toBuffer();
      images.push({ id: randomUUID(), mimeType: "image/jpeg", bytes });
    } catch {
      fail(400, "INVALID_PHOTO");
    }
  }
  return images;
}

export async function attachReportPhotos(tx, reportId, photos) {
  if (!photos.length) return;
  await tx.mediaAsset.createMany({ data: photos });
  await tx.reportImage.createMany({ data: photos.map(({ id, bytes, mimeType }, sortOrder) => ({
    reportId, storageKey: id, mimeType, byteSize: bytes.length, sortOrder,
  })) });
}

export async function serveMedia(prisma, id, actor) {
  if (!uuidPattern.test(id)) fail(404, "NOT_FOUND");
  const publicImage = await prisma.reportImage.findFirst({
    where: { storageKey: id, report: { deletedAt: null } }, select: { id: true },
  });
  if (!publicImage) {
    const permissions = [{ status: "APPROVED" }];
    if (actor) permissions.push({ proposerUid: actor.uid });
    const evidence = await prisma.resolutionProposal.findFirst({
      where: {
        evidenceStorageKey: id, report: { deletedAt: null },
        ...(actor?.admin ? {} : { OR: permissions }),
      },
      select: { id: true },
    });
    if (!evidence) fail(404, "NOT_FOUND");
  }
  const media = await prisma.mediaAsset.findUnique({ where: { id } });
  if (!media) fail(404, "NOT_FOUND");
  return new Response(media.bytes, {
    headers: {
      "Content-Type": media.mimeType, "Content-Length": String(media.bytes.length),
      "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff",
    },
  });
}
