import { audit, boundedText, writeOptions } from "./domain.js";
import { fail, json } from "./http.js";

export async function readProfile(prisma, actor, adminRoute) {
  const user = await prisma.user.findUnique({ where: { id: actor.uid }, select: { publicName: true } });
  const data = { publicName: user?.publicName ?? null };
  if (!adminRoute) Object.assign(data, { uid: actor.uid, role: actor.admin ? "ADMIN" : "CITIZEN" });
  return json({ data });
}

export async function saveProfile(prisma, actor, body) {
  const publicName = boundedText(body.publicName, 2, 50);
  if (!publicName) fail(400, "INVALID_PROFILE");
  const id = actor.uid;
  await prisma.$transaction(async (tx) => {
    await tx.user.upsert({ where: { id }, create: { id }, update: {} });
    const completed = await tx.user.updateMany({ where: { id, publicName: null }, data: { publicName } });
    const changed = completed.count || (await tx.user.updateMany({
      where: { id, publicName: { not: publicName } }, data: { publicName },
    })).count;
    if (changed) {
      await audit(tx, actor, completed.count ? "PROFILE_COMPLETED" : "PROFILE_UPDATED",
        "USER", id, { changedFields: ["public_name"] });
    }
  }, writeOptions);
  return json({ data: { publicName } });
}
