import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/errors/repository_exception.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/categories/data/sqlite_category_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';

import '../support/local_fixture.dart';

Matcher error(RepositoryError code) =>
    isA<RepositoryException>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalFixture fixture;
  setUp(() async {
    fixture = LocalFixture();
    await fixture.initialize();
  });
  tearDown(() => fixture.db.close());

  test('create persists photos, initial history, private revision and audit atomically', () async {
    final id = await fixture.reports.create(fixture.draft());
    final detail = (await fixture.reports.getReport(id))!;
    expect(detail.title, 'Bache en avenida');
    expect(detail.status, ReportStatus.reported);
    expect(detail.publicAuthor, 'Ciudadano anónimo');
    expect(detail.revision, 0);
    expect(detail.photos.single.relativePath, 'photos/a.jpg');
    expect(detail.createdAt.isUtc, isTrue);
    expect(
      await fixture.db
          .customSelect('SELECT * FROM report_status_history')
          .get(),
      hasLength(1),
    );
    expect(
      await fixture.db.customSelect('SELECT * FROM report_revisions').get(),
      hasLength(1),
    );
    expect(
      await fixture.db
          .customSelect(
            "SELECT * FROM audit_events WHERE action='REPORT_CREATED'",
          )
          .get(),
      hasLength(1),
    );
  });

  test(
    'visitor, missing identity and incomplete profile cannot write',
    () async {
      fixture.uid = null;
      await expectLater(
        fixture.reports.create(fixture.draft()),
        throwsA(error(RepositoryError.unauthenticated)),
      );
      fixture.uid = 'unknown';
      await expectLater(
        fixture.reports.create(fixture.draft()),
        throwsA(error(RepositoryError.unauthenticated)),
      );
      fixture.uid = 'new-user';
      await fixture.users.recordGoogleSignIn(uid: 'new-user');
      await expectLater(
        fixture.reports.create(fixture.draft()),
        throwsA(error(RepositoryError.forbidden)),
      );
      expect(
        await fixture.db.customSelect('SELECT * FROM reports').get(),
        isEmpty,
      );
    },
  );

  test(
    'missing photo requests reattachment and does not create partial rows',
    () async {
      fixture.photos.paths.clear();
      await expectLater(
        fixture.reports.create(fixture.draft()),
        throwsA(isA<PhotoStorageException>()),
      );
      expect(
        await fixture.db.customSelect('SELECT * FROM reports').get(),
        isEmpty,
      );
      expect(
        await fixture.db.customSelect('SELECT * FROM report_images').get(),
        isEmpty,
      );
    },
  );

  test(
    'rejects invalid title, disabled category, no photos and path traversal',
    () async {
      await expectLater(
        fixture.reports.create(fixture.draft(title: 'corto')),
        throwsA(error(RepositoryError.invalidInput)),
      );
      await expectLater(
        fixture.reports.create(fixture.draft(images: [])),
        throwsA(error(RepositoryError.invalidInput)),
      );
      await expectLater(
        fixture.reports.create(
          fixture.draft(
            images: [
              const StoredPhoto(
                relativePath: '../a.jpg',
                mimeType: 'image/jpeg',
                bytes: 100,
              ),
            ],
          ),
        ),
        throwsA(error(RepositoryError.invalidInput)),
      );
      await fixture.db.customStatement(
        "UPDATE categories SET is_active=0 WHERE id='baches'",
      );
      await expectLater(
        fixture.reports.create(fixture.draft()),
        throwsA(error(RepositoryError.invalidInput)),
      );
    },
  );

  test('public name is a snapshot and update preserves prior photos in private revisions', () async {
    final id = await fixture.reports.create(
      fixture.draft(identity: PublicIdentityMode.publicName),
    );
    await fixture.users.completePublicName('Nuevo nombre');
    expect((await fixture.reports.getReport(id))!.publicAuthor, 'Vecina');
    await fixture.reports.update(
      reportId: id,
      expectedRevision: 0,
      reason: 'Se corrige la descripción',
      draft: fixture.draft(
        title: 'Bache en avenida principal',
        identity: PublicIdentityMode.publicName,
        images: [
          const StoredPhoto(
            relativePath: 'photos/b.jpg',
            mimeType: 'image/jpeg',
            bytes: 2000,
          ),
        ],
      ),
    );
    final after = (await fixture.reports.getReport(id))!;
    expect(after.publicAuthor, 'Vecina');
    expect(after.revision, 1);
    expect(after.photos.single.relativePath, 'photos/b.jpg');
    final versions = await fixture.db
        .customSelect(
          'SELECT snapshot_json FROM report_revisions ORDER BY revision',
        )
        .get();
    expect(versions, hasLength(2));
    final old = jsonDecode(
      versions.first.read<String>('snapshot_json'),
    ) as Map<String, dynamic>;
    expect(old['images'][0]['local_relative_path'], 'photos/a.jpg');
    expect(fixture.photos.paths, contains('photos/a.jpg'));
  });

  test(
    'stale revision and another user cannot overwrite or delete report',
    () async {
      final id = await fixture.reports.create(fixture.draft());
      await expectLater(
        fixture.reports.update(
          reportId: id,
          draft: fixture.draft(),
          expectedRevision: 99,
          reason: 'Corrección de datos',
        ),
        throwsA(error(RepositoryError.conflict)),
      );
      fixture.uid = 'other';
      await fixture.users.recordGoogleSignIn(uid: 'other');
      await fixture.users.completePublicName('Otro vecino');
      await expectLater(
        fixture.reports.update(
          reportId: id,
          draft: fixture.draft(),
          expectedRevision: 0,
          reason: 'Corrección de datos',
        ),
        throwsA(error(RepositoryError.forbidden)),
      );
      await expectLater(
        fixture.reports.softDelete(reportId: id, reason: 'Reporte duplicado'),
        throwsA(error(RepositoryError.forbidden)),
      );
      expect((await fixture.reports.getReport(id))!.revision, 0);
    },
  );

  test('author cannot edit in follow up but admin can without becoming public author', () async {
    final id = await fixture.reports.create(
      fixture.draft(identity: PublicIdentityMode.publicName),
    );
    await fixture.db.customStatement(
      "UPDATE reports SET status='IN_FOLLOW_UP' WHERE id=?",
      [id],
    );
    await expectLater(
      fixture.reports.update(
        reportId: id,
        draft: fixture.draft(),
        expectedRevision: 0,
        reason: 'Corrección de datos',
      ),
      throwsA(error(RepositoryError.forbidden)),
    );
    fixture.uid = 'admin';
    await fixture.users.recordGoogleSignIn(uid: 'admin');
    await fixture.users.completePublicName('Administración');
    // Trusted provisioning is configured in TASK-005, never via public profile.
    await fixture.db.customStatement(
      "UPDATE users SET role='ADMIN' WHERE id='admin'",
    );
    await fixture.reports.update(
      reportId: id,
      draft: fixture.draft(
        title: 'Bache en avenida principal',
        identity: PublicIdentityMode.publicName,
      ),
      expectedRevision: 0,
      reason: 'Corrección administrativa',
    );
    expect((await fixture.reports.getReport(id))!.publicAuthor, 'Vecina');
  });

  test('soft deletion hides report and preserves actor, photos, revisions and history', () async {
    final id = await fixture.reports.create(fixture.draft());
    await fixture.reports.softDelete(
      reportId: id,
      reason: 'Se registró por error',
    );
    expect(await fixture.reports.getReport(id), isNull);
    expect(await fixture.reports.watchReports().first, isEmpty);
    final deleted = await fixture.db
        .customSelect('SELECT deleted_by_uid,deletion_reason FROM reports')
        .getSingle();
    expect(deleted.read<String>('deleted_by_uid'), 'owner');
    expect(deleted.read<String>('deletion_reason'), 'Se registró por error');
    expect(
      await fixture.db.customSelect('SELECT * FROM report_images').get(),
      hasLength(1),
    );
    expect(
      await fixture.db
          .customSelect('SELECT * FROM report_status_history')
          .get(),
      hasLength(1),
    );
    expect(
      await fixture.db.customSelect('SELECT * FROM report_revisions').get(),
      hasLength(2),
    );
    await expectLater(
      fixture.reports.softDelete(reportId: id, reason: 'Se registró por error'),
      throwsA(error(RepositoryError.notFound)),
    );
  });

  test(
    'audit insertion failure rolls back report, photos and history',
    () async {
      await fixture.db.customStatement(
        "CREATE TRIGGER reject_report_audit BEFORE INSERT ON audit_events WHEN NEW.action='REPORT_CREATED' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        fixture.reports.create(fixture.draft()),
        throwsA(anything),
      );
      for (final table in [
        'reports',
        'report_images',
        'report_revisions',
        'report_status_history',
      ]) {
        expect(
          await fixture.db.customSelect('SELECT * FROM $table').get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'watch emits committed creation and deletion without resubscribing',
    () async {
      final values = <int>[];
      final created = Completer<void>();
      final deleted = Completer<void>();
      final initial = Completer<void>();
      final subscription = fixture.reports.watchReports().listen((reports) {
        values.add(reports.length);
        if (!initial.isCompleted) initial.complete();
        if (reports.length == 1 && !created.isCompleted) created.complete();
        if (created.isCompleted && reports.isEmpty && !deleted.isCompleted) {
          deleted.complete();
        }
      });
      try {
        await initial.future.timeout(const Duration(seconds: 5));
        final id = await fixture.reports.create(fixture.draft());
        await created.future.timeout(const Duration(seconds: 5));
        await fixture.reports.softDelete(
          reportId: id,
          reason: 'Se registró por error',
        );
        await deleted.future.timeout(const Duration(seconds: 5));
        expect(values, [0, 1, 0]);
      } finally {
        await subscription.cancel();
      }
    },
  );

  test(
    'category subscriptions return stable catalog on every new subscription',
    () async {
      final categories = SqliteCategoryRepository(fixture.db);
      expect(await categories.watchCategories().first, hasLength(8));
      expect(await categories.watchCategories().first, hasLength(8));
    },
  );

  test(
    'Google sign in preserves role and public name; audit excludes email',
    () async {
      await fixture.db.customStatement(
        "UPDATE users SET role='ADMIN' WHERE id='owner'",
      );
      await fixture.users.recordGoogleSignIn(
        uid: 'owner',
        email: 'updated-private@example.test',
      );
      final user = await fixture.session.requireCompleteProfile();
      expect(user.publicName, 'Vecina');
      expect(user.role.name, 'admin');
      final rows = await fixture.db
          .customSelect('SELECT * FROM audit_events')
          .get();
      expect(
        jsonEncode(rows.map((row) => row.data).toList()),
        isNot(contains('@example.test')),
      );
    },
  );
}
