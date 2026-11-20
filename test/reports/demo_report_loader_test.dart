import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';
import 'package:reporte_ciudadano_mvp/features/map/data/sqlite_map_report_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/demo_report_loader.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_read_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_filter.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/data/sqlite_statistics_repository.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/domain/statistics_repository.dart';

import '../support/local_fixture.dart';
import '../support/map_fakes.dart';

void main() {
  testWidgets(
    'visitor opts in to demo without login, duplicates, or mixed statistics',
    (tester) async {
      final fixture = LocalFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        await fixture.reports.create(fixture.draft());
      });
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: fixture.db,
            location: TestLocation(),
            tiles: TestTiles.new,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();
        expect(find.text('Estás explorando como visitante.'), findsOneWidget);
        final load = find.text('Cargar reportes de demostración');
        await tester.ensureVisible(load);
        await tester.tap(load);
        for (
          var step = 0;
          step < 50 && find.text('Ejemplos cargados').evaluate().isEmpty;
          step++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(find.text('Ejemplos cargados'), findsOneWidget);
        await tester.runAsync(() async {
          final db = fixture.db;
          expect(await DemoReportLoader(db).load(), isFalse);
          final list = await SqliteReportReadRepository(db)
              .watchList(const ReportFilter())
              .first;
          expect(list.where((report) => report.isDemo), hasLength(3));
          expect(
            list.where((report) => !report.isDemo).single.title,
            'Bache en avenida',
          );
          final markers = await SqliteMapReportRepository(db)
              .watchMarkers()
              .first;
          expect(markers.where((marker) => marker.isDemo), hasLength(3));
          final stats = await SqliteStatisticsRepository(db)
              .watch(const StatisticsFilter(includeDemo: true))
              .first;
          expect(stats.local.total, 1);
          expect(stats.demo!.total, 3);
          expect(stats.demo!.averageResolutionTime, const Duration(hours: 12));
          final resolved = list.singleWhere(
            (report) => report.resolvedAt != null,
          );
          final detail = await SqliteReportReadRepository(db)
              .watchDetail(resolved.id)
              .first;
          expect(detail!.activity, hasLength(2));
          expect(detail.activity.every((entry) => entry.demo), isTrue);
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.db.close);
      }
    },
  );
}
