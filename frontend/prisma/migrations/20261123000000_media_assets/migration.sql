CREATE TABLE "media_assets" (
  "id" UUID NOT NULL,
  "mime_type" TEXT NOT NULL CHECK ("mime_type" = 'image/jpeg'),
  "bytes" BYTEA NOT NULL CHECK (octet_length("bytes") BETWEEN 1 AND 10485760),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);
