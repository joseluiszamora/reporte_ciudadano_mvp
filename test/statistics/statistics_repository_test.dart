import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:reporte_ciudadano_mvp/core/errors/repository_exception.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_resolution_repository.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/data/sqlite_statistics_repository.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/domain/statistics_repository.dart';

import '../support/local_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalFixture f;
  late SqliteStatisticsRepository repository;
  var sequence = 0;
  final origin = DateTime.utc(2026, 11, 19, 12);
  late DateTime now;
  Future<String> create({
    String category = 'baches',
    String status = 'REPORTED',
    DateTime? created,
    DateTime? resolved,
    bool demo = false,
    bool deleted = false,
  }) async {
    f.now = created ?? origin;
    final path = 'photos/stats-${++sequence}.jpg';
    f.photos.paths.add(path);
    final id = await f.reports.create(
      f.draft(
        category: category,
        images: [
          StoredPhoto(relativePath: path, mimeType: 'image/jpeg', bytes: 100),
        ],
      ),
    );
    await f.db.customStatement(
      'UPDATE reports SET status=?,resolved_at=?,is_demo=? WHERE id=?',
      [status, resolved?.toIso8601String(), demo ? 1 : 0, id],
    );
    if (deleted) {
      await f.reports.softDelete(
        reportId: id,
        reason: 'Se registró un duplicado',
      );
    }
    return id;
  }

  Future<LocalStatistics> read([
    StatisticsFilter filter = const StatisticsFilter(),
  ]) => repository.watch(filter).first;
  setUp(() async {
    f = LocalFixture();
    await f.initialize();
    now = origin.add(const Duration(days: 10));
    repository = SqliteStatisticsRepository(
      f.db,
      clock: () => now,
      ticks: () => const Stream.empty(),
    );
  });
  tearDown(() => f.db.close());

  test(
    'empty public statistics return zero counts and no fabricated time samples',
    () async {
      f.uid = null;
      final data = await read();
      expect(data.local.total, 0);
      expect(data.local.reported, 0);
      expect(data.local.inFollowUp, 0);
      expect(data.local.resolved, 0);
      expect(data.local.averagePendingAge, isNull);
      expect(data.local.oldestPendingAge, isNull);
      expect(data.local.averageResolutionTime, isNull);
      expect(data.local.categories, isEmpty);
      expect(data.demo, isNull);
      expect(data.asOf, now);
    },
  );

  test('counts report states/category once, excludes deleted rows and calculates exact pending and resolved means', () async {
    await create();
    await create(
      category: 'basura',
      status: 'IN_FOLLOW_UP',
      created: origin.add(const Duration(days: 4)),
    );
    await create(
      status: 'RESOLVED',
      resolved: origin.add(const Duration(hours: 6)),
    );
    await create(
      category: 'basura',
      status: 'RESOLVED',
      resolved: origin.add(const Duration(hours: 18)),
    );
    await create(
      category: 'otros',
      created: origin.subtract(const Duration(days: 100)),
      deleted: true,
    );
    final group = (await read()).local;
    expect(group.total, 4);
    expect(group.reported, 1);
    expect(group.inFollowUp, 1);
    expect(group.resolved, 2);
    expect(group.pending, 2);
    expect(group.averagePendingAge, const Duration(days: 8));
    expect(group.oldestPendingAge, const Duration(days: 10));
    expect(group.averageResolutionTime, const Duration(hours: 12));
    expect(group.categories.map((c) => '${c.id}:${c.total}'), [
      'baches:2',
      'basura:2',
    ]);
    expect(() => group.categories.clear(), throwsUnsupportedError);
  });

  test('creation dates are inclusive/exclusive UTC instants; category filtering is parameterized and historical inactive categories remain', () async {
    await create(created: origin.subtract(const Duration(microseconds: 1)));
    await create(created: origin);
    await create(created: origin.add(const Duration(microseconds: 1)));
    await create(
      category: 'basura',
      created: origin.add(const Duration(hours: 1)),
    );
    await create(created: origin.add(const Duration(days: 1)));
    await create(created: origin.add(const Duration(days: 1, microseconds: 1)));
    await f.db.customStatement(
      "UPDATE categories SET is_active=0 WHERE id='baches'",
    );
    final filter = StatisticsFilter(
      categoryId: 'baches',
      from: DateTime.parse('2026-11-19T08:00:00-04:00'),
      until: origin.add(const Duration(days: 1)),
    );
    final group = (await read(filter)).local;
    expect(group.total, 2);
    expect(group.categories.single.isActive, isFalse);
    expect((await read(StatisticsFilter(until: origin))).local.total, 1);
    expect(
      (await read(StatisticsFilter(from: origin.add(const Duration(days: 1)))))
          .local
          .total,
      2,
    );
    expect(
      (await read(const StatisticsFilter(categoryId: "baches' OR 1=1--")))
          .local
          .total,
      0,
    );
    await expectLater(
      read(StatisticsFilter(from: origin, until: origin)),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('demo is opt-in and separate; neither its counts nor extreme durations change local averages', () async {
    await create(
      status: 'RESOLVED',
      resolved: origin.add(const Duration(hours: 2)),
    );
    await create(
      status: 'RESOLVED',
      resolved: origin.add(const Duration(days: 50)),
      demo: true,
    );
    await create(category: 'otros', demo: true);
    await create(demo: true, deleted: true);
    final ordinary = await read();
    final included = await read(const StatisticsFilter(includeDemo: true));
    expect(ordinary.demo, isNull);
    expect(ordinary.local.total, 1);
    expect(included.local.total, 1);
    expect(included.local.averageResolutionTime, const Duration(hours: 2));
    expect(included.demo!.total, 2);
    expect(included.demo!.resolved, 1);
    expect(included.demo!.reported, 1);
    expect(included.demo!.averageResolutionTime, const Duration(days: 50));
    expect(included.demo!.categories.map((c) => c.id), ['baches', 'otros']);
    final onlyDemo = await read(
      const StatisticsFilter(categoryId: 'otros', includeDemo: true),
    );
    expect(onlyDemo.local.total, 0);
    expect(onlyDemo.demo!.total, 1);
  });

  test('all local accounts contribute without exposing their identities; joins never multiply by photos or proposals', () async {
    final id = await create();
    await f.db.customStatement(
      '''INSERT INTO report_images(id,report_id,local_relative_path,mime_type,byte_size,sort_order,created_at)
      VALUES(?,?,?,?,?,?,?)''',
      [
        'extra',
        id,
        'photos/extra.jpg',
        'image/jpeg',
        100,
        1,
        origin.toIso8601String(),
      ],
    );
    for (var index = 0; index < 2; index++) {
      await f.db.customStatement(
        '''INSERT INTO resolution_proposals(id,report_id,proposer_uid,note,status,evidence_image_path,created_at,reviewed_at,reviewer_uid,review_note)
        VALUES(?,?,?,?,?,?,?,?,?,?)''',
        [
          'p$index',
          id,
          'owner',
          'La propuesta no es válida',
          'REJECTED',
          'photos/a.jpg',
          origin.toIso8601String(),
          origin.toIso8601String(),
          'owner',
          'Revisión de prueba rechazada',
        ],
      );
    }
    f.uid = 'second';
    await f.users.recordGoogleSignIn(uid: 'second');
    await f.users.completePublicName('Otro vecino');
    await create();
    f.uid = null;
    expect((await read()).local.total, 2);
  });

  test('clock rollback clamps pending age to zero and sub-hour resolution averages preserve precision', () async {
    await create(created: now.add(const Duration(days: 1)));
    await create(
      status: 'RESOLVED',
      resolved: origin.add(const Duration(minutes: 10)),
    );
    await create(
      status: 'RESOLVED',
      resolved: origin.add(const Duration(minutes: 11)),
    );
    final group = (await read()).local;
    expect(group.averagePendingAge, Duration.zero);
    expect(group.oldestPendingAge, Duration.zero);
    expect(
      group.averageResolutionTime,
      const Duration(minutes: 10, seconds: 30),
    );
  });

  test('real approval/reopen/second approval moves samples and uses creation to last resolution, ignoring pending proposals', () async {
    final id = await create();
    final resolutions = SqliteResolutionRepository(
      f.db,
      f.session,
      f.photos,
      clock: () => f.now,
    );
    Future<String> propose() => resolutions.propose(
      reportId: id,
      note: 'Se reparó el tramo afectado',
      photo: const StoredPhoto(
        relativePath: 'photos/b.jpg',
        mimeType: 'image/jpeg',
        bytes: 100,
      ),
      requestId: const Uuid().v4(),
    );
    final first = await propose();
    expect((await read()).local.resolved, 0);
    await f.db.customStatement(
      "UPDATE users SET role='ADMIN' WHERE id='owner'",
    );
    f.now = origin.add(const Duration(hours: 4));
    await resolutions.approve(
      proposalId: first,
      reason: 'Evidencia verificada',
    );
    expect(
      (await read()).local.averageResolutionTime,
      const Duration(hours: 4),
    );
    await resolutions.reopen(
      reportId: id,
      reason: 'Nueva incidencia en el mismo tramo',
    );
    final reopened = (await read()).local;
    expect(reopened.resolved, 0);
    expect(reopened.averageResolutionTime, isNull);
    expect(reopened.inFollowUp, 1);
    expect(reopened.averagePendingAge, const Duration(days: 10));
    final second = await propose();
    f.now = origin.add(const Duration(days: 2));
    await resolutions.approve(
      proposalId: second,
      reason: 'Reparación final verificada',
    );
    expect((await read()).local.averageResolutionTime, const Duration(days: 2));
  });

  test('subscription refreshes on commit and clock ticks, suppresses rollback notifications and releases tick subscription', () async {
    var canceled = false;
    final ticks = StreamController<void>(onCancel: () => canceled = true);
    repository = SqliteStatisticsRepository(
      f.db,
      clock: () => now,
      ticks: () => ticks.stream,
    );
    final values = <LocalStatistics>[];
    var next = Completer<void>();
    final subscription = repository.watch(const StatisticsFilter()).listen((
      data,
    ) {
      values.add(data);
      if (!next.isCompleted) next.complete();
    });
    Future<void> received() => next.future.timeout(const Duration(seconds: 5));
    try {
      await received();
      next = Completer<void>();
      final id = await create();
      await received();
      expect(values.last.local.total, 1);
      next = Completer<void>();
      now = now.add(const Duration(hours: 2));
      ticks.add(null);
      await received();
      expect(
        values.last.local.averagePendingAge,
        const Duration(days: 10, hours: 2),
      );
      final countBefore = values.length;
      await expectLater(
        f.db.transaction(() async {
          await f.db.customStatement(
            "UPDATE reports SET title='Cambio descartado' WHERE id=?",
            [id],
          );
          f.db.changed({'reports'});
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      // A marker tick follows any queued updates, making rollback observable without sleeping.
      next = Completer<void>();
      ticks.add(null);
      await received();
      expect(values.length, countBefore + 1);
      next = Completer<void>();
      await f.reports.softDelete(
        reportId: id,
        reason: 'Se elimina el duplicado',
      );
      await received();
      expect(values.last.local.total, 0);
    } finally {
      await subscription.cancel();
      await ticks.close();
    }
    expect(canceled, isTrue);
  });
}
