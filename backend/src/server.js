import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { PrismaClient } from "./generated/prisma/client.ts";
import { createApp } from "./app.js";

const { DATABASE_URL, FIREBASE_PROJECT_ID, HOST = "127.0.0.1", PORT = "3000" } = process.env;
const port = Number(PORT);

if (!DATABASE_URL || !/^postgres(?:ql)?:\/\//.test(DATABASE_URL)) {
  throw new Error("Configura DATABASE_URL con una URL de PostgreSQL.");
}
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error("Configura PORT con un entero entre 1 y 65535.");
}

const adapter = new PrismaPg({ connectionString: DATABASE_URL, connectionTimeoutMillis: 5_000 });
const prisma = new PrismaClient({ adapter });
const auth = FIREBASE_PROJECT_ID ? getAuth(initializeApp({ projectId: FIREBASE_PROJECT_ID })) : null;
const verifyToken = auth ? (token) => auth.verifyIdToken(token) : undefined;
const server = createApp(prisma, { verifyToken }).listen(port, HOST, () => {
  console.log(`API de reportes en http://${HOST}:${port}`);
});

function shutdown() {
  server.close(async (error) => {
    try {
      await prisma.$disconnect();
      if (error) process.exitCode = 1;
    } catch (disconnectError) {
      console.error("Error al cerrar PostgreSQL:", disconnectError.name);
      process.exitCode = 1;
    }
  });
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
