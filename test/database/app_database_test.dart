import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'bootstrap enables foreign keys and seeds exactly eight categories',
    () async {
      final rows = await db.customSelect('SELECT * FROM categories').get();
      expect(rows, hasLength(8));
      final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(pragma.read<int>('foreign_keys'), 1);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  Future<void> seedReport() async {
    await db.customStatement(
      "INSERT INTO users(id,public_name,created_at,last_sign_in_at) VALUES('u','Vecina','2026-11-19T00:00:00.000Z','2026-11-19T00:00:00.000Z')",
    );
    await db.customStatement("""
      INSERT INTO reports(id,author_uid,category_id,title,description,latitude,longitude,public_identity_mode,created_at,updated_at)
      VALUES('r','u','baches','Bache en avenida','Un bache afecta el paso de vehículos.',-16.5,-68.15,'ANONYMOUS','2026-11-19T00:00:00.000Z','2026-11-19T00:00:00.000Z')
    """);
  }

  test('constraints reject broken references and invalid resolution', () async {
    await seedReport();
    await expectLater(
      db.customStatement(
        "UPDATE reports SET category_id='missing' WHERE id='r'",
      ),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement("UPDATE reports SET status='RESOLVED' WHERE id='r'"),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement(
        "UPDATE reports SET deleted_at='2026-11-19T01:00:00.000Z' WHERE id='r'",
      ),
      throwsA(anything),
    );
  });

  test(
    'transaction rollback does not leave a partially resolved report',
    () async {
      await seedReport();
      await expectLater(
        db.transaction(() async {
          await db.customStatement(
            "UPDATE reports SET status='RESOLVED',resolved_at='2026-11-19T01:00:00.000Z' WHERE id='r'",
          );
          await db.customStatement(
            "INSERT INTO audit_events(id,actor_role,action,entity_type,created_at) VALUES('e','INVALID','PROPOSAL_APPROVED','report','2026-11-19T01:00:00.000Z')",
          );
        }),
        throwsA(anything),
      );
      final report = await db
          .customSelect("SELECT status,resolved_at FROM reports WHERE id='r'")
          .getSingle();
      expect(report.read<String>('status'), 'REPORTED');
      expect(report.data['resolved_at'], isNull);
    },
  );
}
