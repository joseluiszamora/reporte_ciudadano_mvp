import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/media/local_photo_reader.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/map/data/sqlite_map_report_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_read_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_filter.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';
import 'package:reporte_ciudadano_mvp/features/reports/presentation/report_labels.dart';

import '../support/local_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalFixture fixture;
  late SqliteReportReadRepository read;
  setUp(() async {
    fixture = LocalFixture();
    await fixture.initialize();
    read = SqliteReportReadRepository(fixture.db);
  });
  tearDown(() => fixture.db.close());

  Future<(String, String)> twoReports() async {
    fixture.now = DateTime.utc(2026, 11, 18, 12);
    final a = await fixture.reports.create(
      fixture.draft(title: 'ÁRBOL bloquea avenida'),
    );
    fixture.now = DateTime.utc(2026, 11, 19, 12);
    final b = await fixture.reports.create(
      fixture.draft(
        title: 'Basura al 100% en calle',
        category: 'basura',
        images: [
          const StoredPhoto(
            relativePath: 'photos/b.jpg',
            mimeType: 'image/jpeg',
            bytes: 100,
          ),
        ],
      ),
    );
    await fixture.db.customStatement(
      "UPDATE reports SET status='IN_FOLLOW_UP' WHERE id=?",
      [b],
    );
    return (a, b);
  }

  test(
    'map and list share text, category, state, date boundaries and order',
    () async {
      final (a, b) = await twoReports();
      final map = SqliteMapReportRepository(fixture.db);
      final cases = [
        const ReportFilter(),
        const ReportFilter(search: 'árbol'),
        const ReportFilter(search: '%'),
        const ReportFilter(
          categoryId: 'basura',
          status: ReportStatus.inFollowUp,
        ),
        ReportFilter(
          from: DateTime.utc(2026, 11, 19, 12),
          until: DateTime.utc(2026, 11, 20),
        ),
        ReportFilter(until: DateTime.utc(2026, 11, 19, 12)),
        const ReportFilter(order: ReportOrder.oldest),
        const ReportFilter(search: "' OR 1=1 --"),
      ];
      for (final filter in cases) {
        final list = await read.watchList(filter).first;
        final markers = await map.watchMarkers(filter: filter).first;
        expect(
          markers.map((item) => item.id).toList(),
          list.map((item) => item.id).toList(),
        );
      }
      expect(
        (await read.watchList(const ReportFilter()).first).map(
          (item) => item.id,
        ),
        [b, a],
      );
      expect(
        (await read.watchList(const ReportFilter(search: 'árbol')).first)
            .single
            .id,
        a,
      );
      expect(
        (await read.watchList(const ReportFilter(search: '%')).first).single.id,
        b,
      );
      expect(
        (await read
                .watchList(ReportFilter(until: DateTime.utc(2026, 11, 19, 12)))
                .first)
            .single
            .id,
        a,
      );
      expect(
        (await read.watchList(const ReportFilter(search: "' OR 1=1 --")).first),
        isEmpty,
      );
    },
  );

  test('public detail preserves anonymity, includes history and proposals without actor IDs', () async {
    final id = await fixture.reports.create(fixture.draft());
    await fixture.db.customStatement(
      '''INSERT INTO resolution_proposals(id,report_id,proposer_uid,note,evidence_image_path,created_at)
      VALUES('proposal',?,'owner','Se adjunta evidencia de reparación','photos/b.jpg','2026-11-19T13:00:00.000Z')''',
      [id],
    );
    final view = (await read.watchDetail(id).first)!;
    expect(view.details.publicAuthor, 'Ciudadano anónimo');
    expect(view.details.status, ReportStatus.reported);
    expect(view.activity.map((item) => item.text), [
      'Reporte creado',
      'Solución propuesta',
    ]);
    expect(view.activity.last.evidencePath, 'photos/b.jpg');
    await fixture.reports.softDelete(reportId: id, reason: 'Reporte duplicado');
    expect(await read.watchDetail(id).first, isNull);
    expect(await read.watchList(const ReportFilter()).first, isEmpty);
  });

  test('inactive category remains searchable for historical reports', () async {
    final id = await fixture.reports.create(fixture.draft());
    await fixture.db.customStatement(
      "UPDATE categories SET is_active=0 WHERE id='baches'",
    );
    expect(
      (await read.watchList(const ReportFilter(categoryId: 'baches')).first)
          .single
          .id,
      id,
    );
  });

  test(
    'elapsed time clamps clock rollback and distinguishes resolved duration',
    () {
      final created = DateTime.utc(2026, 11, 19, 12);
      expect(
        ReportLabels.elapsed(
          created,
          null,
          created.subtract(const Duration(hours: 1)),
        ),
        'Tiempo pendiente: 0 min',
      );
      expect(
        ReportLabels.elapsed(
          created,
          created.add(const Duration(hours: 26)),
          created,
        ),
        'Resuelto en: 1 día 2 h',
      );
    },
  );

  test('photo reader confines paths to private directory and handles missing files', () async {
    final root = await Directory.systemTemp.createTemp('citizen_photos_');
    try {
      final reader = PrivatePhotoReader(directory: () async => root);
      await Directory('${root.path}/photos').create();
      await File('${root.path}/photos/a.jpg').writeAsBytes([1, 2, 3]);
      expect(await reader.open('photos/a.jpg'), isNotNull);
      expect(await reader.open('photos/missing.jpg'), isNull);
      expect(await reader.open('../outside.jpg'), isNull);
      expect(await reader.open('C:\\private.jpg'), isNull);
      expect(await reader.open('/outside.jpg'), isNull);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
