BEGIN;

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('CITIZEN', 'ADMIN');

-- CreateEnum
CREATE TYPE "AuditRole" AS ENUM ('VISITOR', 'CITIZEN', 'ADMIN', 'SYSTEM');

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('REPORTED', 'IN_FOLLOW_UP', 'RESOLVED');

-- CreateEnum
CREATE TYPE "PublicIdentityMode" AS ENUM ('PUBLIC_NAME', 'ANONYMOUS');

-- CreateEnum
CREATE TYPE "ProposalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "public_name" VARCHAR(50),
    "role" "Role" NOT NULL DEFAULT 'CITIZEN',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_sign_in_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "icon_key" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reports" (
    "id" UUID NOT NULL,
    "author_uid" TEXT NOT NULL,
    "category_id" TEXT NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "description" VARCHAR(2000) NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "address_label" TEXT,
    "status" "ReportStatus" NOT NULL DEFAULT 'REPORTED',
    "public_identity_mode" "PublicIdentityMode" NOT NULL,
    "public_name_snapshot" VARCHAR(50),
    "revision" INTEGER NOT NULL DEFAULT 0,
    "is_demo" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(3),
    "deleted_at" TIMESTAMPTZ(3),
    "deleted_by_uid" TEXT,
    "deletion_reason" VARCHAR(1000),

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "report_images" (
    "id" UUID NOT NULL,
    "report_id" UUID NOT NULL,
    "storage_key" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "report_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "resolution_proposals" (
    "id" UUID NOT NULL,
    "report_id" UUID NOT NULL,
    "proposer_uid" TEXT NOT NULL,
    "note" VARCHAR(1000) NOT NULL,
    "status" "ProposalStatus" NOT NULL DEFAULT 'PENDING',
    "evidence_storage_key" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMPTZ(3),
    "reviewer_uid" TEXT,
    "review_note" VARCHAR(1000),
    "is_demo_review" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "resolution_proposals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "report_status_history" (
    "id" UUID NOT NULL,
    "report_id" UUID NOT NULL,
    "from_status" "ReportStatus",
    "to_status" "ReportStatus" NOT NULL,
    "actor_uid" TEXT NOT NULL,
    "proposal_id" UUID,
    "note" VARCHAR(1000) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_demo_action" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "report_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "report_revisions" (
    "report_id" UUID NOT NULL,
    "revision" INTEGER NOT NULL,
    "snapshot" JSONB NOT NULL,
    "changed_by_uid" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "report_revisions_pkey" PRIMARY KEY ("report_id","revision")
);

-- CreateTable
CREATE TABLE "audit_events" (
    "id" UUID NOT NULL,
    "actor_uid" TEXT,
    "actor_role" "AuditRole" NOT NULL,
    "action" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT,
    "changed_fields" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_demo" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- CreateIndex
CREATE INDEX "reports_is_demo_deleted_at_created_at_id_idx" ON "reports"("is_demo", "deleted_at", "created_at", "id");

-- CreateIndex
CREATE INDEX "reports_category_id_idx" ON "reports"("category_id");

-- CreateIndex
CREATE INDEX "reports_status_idx" ON "reports"("status");

-- CreateIndex
CREATE INDEX "reports_author_uid_idx" ON "reports"("author_uid");

-- CreateIndex
CREATE UNIQUE INDEX "report_images_storage_key_key" ON "report_images"("storage_key");

-- CreateIndex
CREATE UNIQUE INDEX "report_images_report_id_sort_order_key" ON "report_images"("report_id", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "resolution_proposals_evidence_storage_key_key" ON "resolution_proposals"("evidence_storage_key");

-- CreateIndex
CREATE INDEX "resolution_proposals_report_id_status_idx" ON "resolution_proposals"("report_id", "status");

-- CreateIndex
CREATE INDEX "report_status_history_report_id_created_at_idx" ON "report_status_history"("report_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_events_actor_uid_created_at_idx" ON "audit_events"("actor_uid", "created_at");

-- CreateIndex
CREATE INDEX "audit_events_action_created_at_idx" ON "audit_events"("action", "created_at");

-- CreateIndex
CREATE INDEX "audit_events_entity_type_entity_id_created_at_idx" ON "audit_events"("entity_type", "entity_id", "created_at");

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_author_uid_fkey" FOREIGN KEY ("author_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_deleted_by_uid_fkey" FOREIGN KEY ("deleted_by_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_images" ADD CONSTRAINT "report_images_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resolution_proposals" ADD CONSTRAINT "resolution_proposals_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resolution_proposals" ADD CONSTRAINT "resolution_proposals_proposer_uid_fkey" FOREIGN KEY ("proposer_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resolution_proposals" ADD CONSTRAINT "resolution_proposals_reviewer_uid_fkey" FOREIGN KEY ("reviewer_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_status_history" ADD CONSTRAINT "report_status_history_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_status_history" ADD CONSTRAINT "report_status_history_actor_uid_fkey" FOREIGN KEY ("actor_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_status_history" ADD CONSTRAINT "report_status_history_proposal_id_fkey" FOREIGN KEY ("proposal_id") REFERENCES "resolution_proposals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_revisions" ADD CONSTRAINT "report_revisions_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "report_revisions" ADD CONSTRAINT "report_revisions_changed_by_uid_fkey" FOREIGN KEY ("changed_by_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_events" ADD CONSTRAINT "audit_events_actor_uid_fkey" FOREIGN KEY ("actor_uid") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Domain constraints that Prisma Schema Language cannot express.
ALTER TABLE "users"
  ADD CONSTRAINT "users_public_name_check"
    CHECK (public_name IS NULL OR char_length(btrim(public_name)) BETWEEN 2 AND 50);

ALTER TABLE "reports"
  ADD CONSTRAINT "reports_title_check" CHECK (char_length(btrim(title)) BETWEEN 10 AND 100),
  ADD CONSTRAINT "reports_description_check" CHECK (char_length(btrim(description)) BETWEEN 20 AND 2000),
  ADD CONSTRAINT "reports_coordinates_check"
    CHECK (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT "reports_revision_check" CHECK (revision >= 0),
  ADD CONSTRAINT "reports_resolution_check"
    CHECK (
      (status = 'RESOLVED') = (resolved_at IS NOT NULL)
      AND (resolved_at IS NULL OR resolved_at >= created_at)
    ),
  ADD CONSTRAINT "reports_public_identity_check"
    CHECK (
      (public_identity_mode = 'ANONYMOUS' AND public_name_snapshot IS NULL)
      OR (public_identity_mode = 'PUBLIC_NAME' AND public_name_snapshot IS NOT NULL
          AND char_length(btrim(public_name_snapshot)) BETWEEN 2 AND 50)
    ),
  ADD CONSTRAINT "reports_deletion_check"
    CHECK (
      (deleted_at IS NULL AND deleted_by_uid IS NULL AND deletion_reason IS NULL)
      OR (deleted_at IS NOT NULL AND deleted_by_uid IS NOT NULL AND deletion_reason IS NOT NULL
          AND char_length(btrim(deletion_reason)) BETWEEN 10 AND 1000)
    );

ALTER TABLE "report_images"
  ADD CONSTRAINT "report_images_mime_type_check" CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
  ADD CONSTRAINT "report_images_byte_size_check" CHECK (byte_size BETWEEN 1 AND 10485760),
  ADD CONSTRAINT "report_images_sort_order_check" CHECK (sort_order BETWEEN 0 AND 4);

ALTER TABLE "resolution_proposals"
  ADD CONSTRAINT "resolution_proposals_note_check" CHECK (char_length(btrim(note)) BETWEEN 10 AND 1000),
  ADD CONSTRAINT "resolution_proposals_review_check"
    CHECK (
      (status = 'PENDING' AND reviewed_at IS NULL AND reviewer_uid IS NULL AND review_note IS NULL)
      OR (status <> 'PENDING' AND reviewed_at IS NOT NULL AND reviewer_uid IS NOT NULL AND review_note IS NOT NULL
          AND char_length(btrim(review_note)) BETWEEN 10 AND 1000)
    );

CREATE UNIQUE INDEX "one_pending_proposal_per_user"
  ON "resolution_proposals"(report_id, proposer_uid) WHERE status = 'PENDING';

ALTER TABLE "report_revisions"
  ADD CONSTRAINT "report_revisions_revision_check" CHECK (revision >= 0);

-- Initial catalog shared with the Android app.
INSERT INTO "categories" (id, slug, name, icon_key, sort_order) VALUES
  ('baches', 'baches', 'Baches y daños en las calles', 'road', 1),
  ('semaforos', 'semaforos', 'Semáforos averiados', 'traffic', 2),
  ('aceras', 'aceras', 'Aceras bloqueadas u ocupadas', 'walk', 3),
  ('alumbrado', 'alumbrado', 'Alumbrado público defectuoso', 'light', 4),
  ('basura', 'basura', 'Basura y acumulación de residuos', 'delete', 5),
  ('drenajes', 'drenajes', 'Alcantarillas o drenajes dañados', 'water', 6),
  ('senales', 'senales', 'Señalización vial dañada o ausente', 'sign', 7),
  ('otros', 'otros', 'Otros problemas urbanos', 'category', 8);

COMMIT;
