ALTER TABLE reports ADD COLUMN revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0);
CREATE INDEX reports_visible_date ON reports(deleted_at, created_at);
CREATE TABLE report_revisions (
  report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE RESTRICT,
  revision INTEGER NOT NULL,
  snapshot_json TEXT NOT NULL,
  changed_by_uid TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL,
  PRIMARY KEY(report_id, revision)
);
