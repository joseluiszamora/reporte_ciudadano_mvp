import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/database/app_database.dart';

import '../support/local_fixture.dart';

/// Reproduces the shipped v1 SQL, without running the v2 migration on create.
class LegacyDatabase extends GeneratedDatabase {
  LegacyDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      final sql = await rootBundle.loadString('assets/database/schema_v1.sql');
      for (final statement in sql.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(
    () async => temp = await Directory.systemTemp.createTemp('citizen_sqlite_'),
  );
  tearDown(() async => temp.delete(recursive: true));

  test('report and photo reference survive close and reopen of actual database file', () async {
    final file = File('${temp.path}/reports.sqlite');
    final fixture = LocalFixture(
      database: AppDatabase.forTesting(NativeDatabase(file)),
    );
    await fixture.initialize();
    final id = await fixture.reports.create(fixture.draft());
    await fixture.db.close();
    final reopened = LocalFixture(
      database: AppDatabase.forTesting(NativeDatabase(file)),
    );
    try {
      final report = (await reopened.reports.getReport(id))!;
      expect(report.title, 'Bache en avenida');
      expect(report.photos.single.relativePath, 'photos/a.jpg');
      expect(
        await reopened.db.customSelect('SELECT * FROM report_revisions').get(),
        hasLength(1),
      );
      expect(
        await reopened.db.customSelect('SELECT * FROM categories').get(),
        hasLength(8),
      );
    } finally {
      await reopened.db.close();
    }
  });

  test(
    'v1 to v2 migration preserves reports, images, history and categories',
    () async {
      final file = File('${temp.path}/legacy.sqlite');
      final legacy = LegacyDatabase(NativeDatabase(file));
      await legacy.customStatement(
        "INSERT INTO users(id,public_name,created_at,last_sign_in_at) VALUES('owner','Vecina','2026-11-19T00:00:00.000Z','2026-11-19T00:00:00.000Z')",
      );
      await legacy.customStatement(
        """INSERT INTO reports(id,author_uid,category_id,title,description,latitude,longitude,public_identity_mode,created_at,updated_at)
      VALUES('legacy','owner','baches','Bache en avenida','Un bache afecta el paso de vehículos.',-16.5,-68.15,'ANONYMOUS','2026-11-19T00:00:00.000Z','2026-11-19T00:00:00.000Z')""",
      );
      await legacy.customStatement(
        "INSERT INTO report_images VALUES('photo','legacy','photos/a.jpg','image/jpeg',1024,0,'2026-11-19T00:00:00.000Z',NULL)",
      );
      await legacy.customStatement(
        "INSERT INTO report_status_history(id,report_id,to_status,actor_uid,note,created_at) VALUES('h','legacy','REPORTED','owner','Reporte creado','2026-11-19T00:00:00.000Z')",
      );
      await legacy.close();
      final upgraded = LocalFixture(
        database: AppDatabase.forTesting(NativeDatabase(file)),
      );
      try {
        final report = (await upgraded.reports.getReport('legacy'))!;
        expect(report.revision, 0);
        expect(report.photos.single.relativePath, 'photos/a.jpg');
        expect(
          await upgraded.db.customSelect('SELECT * FROM categories').get(),
          hasLength(8),
        );
        expect(
          await upgraded.db
              .customSelect('SELECT * FROM report_status_history')
              .get(),
          hasLength(1),
        );
        expect(
          await upgraded.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await upgraded.reports.update(
          reportId: 'legacy',
          draft: upgraded.draft(title: 'Bache en avenida principal'),
          expectedRevision: 0,
          reason: 'Actualización tras migración',
        );
        expect(
          await upgraded.db
              .customSelect('SELECT * FROM report_revisions')
              .get(),
          hasLength(2),
        );
      } finally {
        await upgraded.db.close();
      }
      final again = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await again.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2,
        );
        expect(
          await again.customSelect('SELECT * FROM categories').get(),
          hasLength(8),
        );
      } finally {
        await again.close();
      }
    },
  );
}
