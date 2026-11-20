import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/audit/audit_repository.dart';
import 'package:reporte_ciudadano_mvp/core/audit/sqlite_audit_repository.dart';
import 'package:reporte_ciudadano_mvp/core/errors/repository_exception.dart';

import '../support/local_fixture.dart';
import 'resolution_repository_test.dart' show failure;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalFixture f;
  late SqliteAuditRepository audit;
  late String id;
  setUp(() async {
    f = LocalFixture();
    await f.initialize();
    id = await f.reports.create(f.draft());
    audit = SqliteAuditRepository(f.db, f.session);
  });
  tearDown(() => f.db.close());

  test('audit read requires current complete admin and checks database role for every query', () async {
    await expectLater(
      audit.query(const AuditFilter()),
      throwsA(failure(RepositoryError.forbidden)),
    );
    f.uid = null;
    await expectLater(
      audit.query(const AuditFilter()),
      throwsA(failure(RepositoryError.unauthenticated)),
    );
    f.uid = 'owner';
    await f.db.customStatement(
      "UPDATE users SET role='ADMIN' WHERE id='owner'",
    );
    expect(await audit.query(const AuditFilter()), isNotEmpty);
    await f.db.customStatement(
      "UPDATE users SET role='CITIZEN' WHERE id='owner'",
    );
    await expectLater(
      audit.query(const AuditFilter()),
      throwsA(failure(RepositoryError.forbidden)),
    );
  });

  test('filters actor action entity dates and demo; deleted report evidence remains queryable without email', () async {
    f.now = f.now.add(const Duration(hours: 2));
    await f.reports.softDelete(
      reportId: id,
      reason: 'Se registró un duplicado',
    );
    await f.db.customStatement(
      "UPDATE users SET role='ADMIN' WHERE id='owner'",
    );
    final results = await audit.query(
      AuditFilter(
        actorUid: 'owner',
        action: 'REPORT_DELETED',
        entityType: 'report',
        entityId: id,
        from: f.now,
        to: f.now.add(const Duration(seconds: 1)),
        isDemo: false,
      ),
    );
    expect(results, hasLength(1));
    expect(results.single['reason'], 'Se registró un duplicado');
    expect(results.single['actor_role'], 'CITIZEN');
    expect(await f.reports.getReport(id), isNull);
    expect(
      await audit.query(AuditFilter(action: 'REPORT_DELETED', to: f.now)),
      isEmpty,
    );
    expect(
      await audit.query(const AuditFilter(actorUid: "owner' OR 1=1--")),
      isEmpty,
    );
    expect(await audit.query(const AuditFilter(isDemo: true)), isEmpty);
    expect(
      jsonEncode(await audit.query(const AuditFilter())),
      isNot(contains('private@example.test')),
    );
    await expectLater(
      audit.query(AuditFilter(from: f.now, to: f.now)),
      throwsA(failure(RepositoryError.invalidInput)),
    );
  });

  test(
    'audit query limit is explicit and newest events appear first',
    () async {
      await f.db.customStatement(
        "UPDATE users SET role='ADMIN' WHERE id='owner'",
      );
      await f.db.transaction(() async {
        for (var index = 0; index < 510; index++) {
          await f.db.customStatement(
            '''INSERT INTO audit_events(id,actor_role,action,entity_type,created_at)
          VALUES(?,?,?,?,?)''',
            [
              'event-$index',
              'SYSTEM',
              'TEST',
              'report',
              f.now.add(Duration(seconds: index)).toIso8601String(),
            ],
          );
        }
      });
      final results = await audit.query(const AuditFilter(action: 'TEST'));
      expect(results, hasLength(SqliteAuditRepository.maxRows));
      expect(results.first['id'], 'event-509');
      expect(results.last['id'], 'event-10');
    },
  );

  test('CSV escapes quotes/newlines and neutralizes formulas, including leading whitespace', () {
    final csv = auditCsv([
      {'id': 'normal', 'reason': 'Contiene "comillas", coma\ny otra línea'},
      {'id': '=1+1', 'reason': '  @SUM(A1)'},
      {'id': '+12', 'reason': '\t=2+3'},
    ]);
    expect(csv, contains('"Contiene ""comillas"", coma\ny otra línea"'));
    expect(csv, contains('"\'=1+1"'));
    expect(csv, contains('"\'  @SUM(A1)"'));
    expect(csv, contains('"\'+12"'));
    expect(csv, contains('"\'\t=2+3"'));
    expect(csv.split('\r\n'), hasLength(4));
  });
}
