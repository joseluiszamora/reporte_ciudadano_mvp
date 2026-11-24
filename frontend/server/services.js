import { PrismaPg } from "@prisma/adapter-pg";
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { PrismaClient } from "./generated/prisma/client.ts";

export function getPrisma() {
  if (globalThis.reportesPrisma) return globalThis.reportesPrisma;
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error("Falta DATABASE_URL");
  const channelBinding = new URL(connectionString).searchParams.get("channel_binding");
  const adapter = new PrismaPg({
    connectionString,
    connectionTimeoutMillis: 10_000,
    enableChannelBinding: channelBinding === "require" || channelBinding === "prefer",
    max: 5,
  });
  return globalThis.reportesPrisma = new PrismaClient({ adapter });
}

export function getVerifier() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) return undefined;
  const name = "reportes-api";
  const app = getApps().find((candidate) => candidate.name === name) ??
    initializeApp({ projectId }, name);
  return (token) => getAuth(app).verifyIdToken(token);
}
