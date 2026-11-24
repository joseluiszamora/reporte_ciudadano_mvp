export default {
  devIndicators: false,
  poweredByHeader: false,
  serverExternalPackages: ["@prisma/adapter-pg", "firebase-admin", "pg", "sharp"],
  async rewrites() {
    return [
      { source: "/health", destination: "/api/v1/health" },
      { source: "/ready", destination: "/api/v1/ready" },
    ];
  },
};
