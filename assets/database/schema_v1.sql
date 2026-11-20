CREATE TABLE users (
  id TEXT PRIMARY KEY,
  public_name TEXT CHECK(public_name IS NULL OR length(trim(public_name)) BETWEEN 2 AND 50),
  email TEXT,
  photo_url TEXT,
  role TEXT NOT NULL DEFAULT 'CITIZEN' CHECK(role IN ('CITIZEN','ADMIN')),
  created_at TEXT NOT NULL,
  last_sign_in_at TEXT NOT NULL
);
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
  server_id TEXT,
  updated_at TEXT NOT NULL
);
CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  author_uid TEXT NOT NULL REFERENCES users(id),
  category_id TEXT NOT NULL REFERENCES categories(id),
  title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 10 AND 100),
  description TEXT NOT NULL CHECK(length(trim(description)) BETWEEN 20 AND 2000),
  latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90),
  longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180),
  address_label TEXT,
  status TEXT NOT NULL DEFAULT 'REPORTED' CHECK(status IN ('REPORTED','IN_FOLLOW_UP','RESOLVED')),
  public_identity_mode TEXT NOT NULL CHECK(public_identity_mode IN ('PUBLIC_NAME','ANONYMOUS')),
  public_name_snapshot TEXT,
  responsible_institution_label TEXT,
  is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  resolved_at TEXT,
  sync_state TEXT NOT NULL DEFAULT 'LOCAL_ONLY' CHECK(sync_state IN ('LOCAL_ONLY','PENDING','SYNCED','CONFLICT')),
  server_id TEXT,
  deleted_at TEXT,
  deleted_by_uid TEXT REFERENCES users(id),
  deletion_reason TEXT,
  CHECK((status = 'RESOLVED' AND resolved_at IS NOT NULL) OR (status <> 'RESOLVED' AND resolved_at IS NULL)),
  CHECK(public_identity_mode = 'ANONYMOUS' OR length(trim(public_name_snapshot)) BETWEEN 2 AND 50),
  CHECK(public_identity_mode <> 'PUBLIC_NAME' OR public_name_snapshot IS NOT NULL),
  CHECK(resolved_at IS NULL OR resolved_at >= created_at),
  CHECK(deleted_at IS NULL OR (deleted_by_uid IS NOT NULL AND deletion_reason IS NOT NULL))
);
CREATE TABLE report_images (
  id TEXT PRIMARY KEY,
  report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE RESTRICT,
  local_relative_path TEXT NOT NULL UNIQUE,
  mime_type TEXT NOT NULL CHECK(mime_type IN ('image/jpeg','image/png','image/webp')),
  byte_size INTEGER NOT NULL CHECK(byte_size BETWEEN 1 AND 10485760),
  sort_order INTEGER NOT NULL CHECK(sort_order BETWEEN 0 AND 4),
  created_at TEXT NOT NULL,
  server_id TEXT,
  UNIQUE(report_id, sort_order)
);
CREATE TABLE resolution_proposals (
  id TEXT PRIMARY KEY,
  report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE RESTRICT,
  proposer_uid TEXT NOT NULL REFERENCES users(id),
  note TEXT NOT NULL CHECK(length(trim(note)) BETWEEN 10 AND 1000),
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','APPROVED','REJECTED')),
  evidence_image_path TEXT NOT NULL,
  created_at TEXT NOT NULL,
  reviewed_at TEXT,
  reviewer_uid TEXT REFERENCES users(id),
  review_note TEXT,
  is_demo_review INTEGER NOT NULL DEFAULT 0 CHECK(is_demo_review IN (0,1)),
  CHECK(status = 'PENDING' OR (reviewed_at IS NOT NULL AND reviewer_uid IS NOT NULL AND review_note IS NOT NULL))
);
CREATE UNIQUE INDEX one_pending_proposal_per_user ON resolution_proposals(report_id, proposer_uid) WHERE status = 'PENDING';
CREATE TABLE report_status_history (
  id TEXT PRIMARY KEY,
  report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE RESTRICT,
  from_status TEXT CHECK(from_status IN ('REPORTED','IN_FOLLOW_UP','RESOLVED')),
  to_status TEXT NOT NULL CHECK(to_status IN ('REPORTED','IN_FOLLOW_UP','RESOLVED')),
  actor_uid TEXT NOT NULL REFERENCES users(id),
  proposal_id TEXT REFERENCES resolution_proposals(id),
  note TEXT NOT NULL,
  created_at TEXT NOT NULL,
  is_demo_action INTEGER NOT NULL DEFAULT 0 CHECK(is_demo_action IN (0,1))
);
CREATE TABLE audit_events (
  id TEXT PRIMARY KEY,
  actor_uid TEXT REFERENCES users(id),
  actor_role TEXT NOT NULL CHECK(actor_role IN ('VISITOR','CITIZEN','ADMIN','SYSTEM')),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  changed_fields_json TEXT NOT NULL DEFAULT '[]',
  reason TEXT,
  created_at TEXT NOT NULL,
  is_demo INTEGER NOT NULL DEFAULT 0 CHECK(is_demo IN (0,1))
);
CREATE INDEX reports_category ON reports(category_id);
CREATE INDEX reports_status ON reports(status);
CREATE INDEX reports_created ON reports(created_at);
CREATE INDEX reports_author ON reports(author_uid);
CREATE INDEX audit_actor_date ON audit_events(actor_uid, created_at);
CREATE INDEX audit_action_date ON audit_events(action, created_at);
CREATE INDEX history_report_date ON report_status_history(report_id, created_at);
INSERT INTO categories(id,slug,name,icon_key,sort_order,updated_at) VALUES
 ('baches','baches','Baches y daños en las calles','road',1,'2026-11-19T00:00:00.000Z'),
 ('semaforos','semaforos','Semáforos averiados','traffic',2,'2026-11-19T00:00:00.000Z'),
 ('aceras','aceras','Aceras bloqueadas u ocupadas','walk',3,'2026-11-19T00:00:00.000Z'),
 ('alumbrado','alumbrado','Alumbrado público defectuoso','light',4,'2026-11-19T00:00:00.000Z'),
 ('basura','basura','Basura y acumulación de residuos','delete',5,'2026-11-19T00:00:00.000Z'),
 ('drenajes','drenajes','Alcantarillas o drenajes dañados','water',6,'2026-11-19T00:00:00.000Z'),
 ('senales','senales','Señalización vial dañada o ausente','sign',7,'2026-11-19T00:00:00.000Z'),
 ('otros','otros','Otros problemas urbanos','category',8,'2026-11-19T00:00:00.000Z');
