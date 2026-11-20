import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/features/map/data/sqlite_map_report_repository.dart';

import '../support/local_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'map reads real report positions and excludes logically deleted reports',
    () async {
      final fixture = LocalFixture();
      await fixture.initialize();
      try {
        final id = await fixture.reports.create(fixture.draft());
        final map = SqliteMapReportRepository(fixture.db);
        final marker = (await map.watchMarkers().first).single;
        expect(marker.id, id);
        expect(marker.point.latitude, -16.5);
        expect(marker.category, 'Baches y daños en las calles');
        expect(marker.categoryIcon, 'road');
        expect(marker.isDemo, isFalse);
        await fixture.reports.softDelete(
          reportId: id,
          reason: 'Reporte duplicado',
        );
        expect(await map.watchMarkers().first, isEmpty);
      } finally {
        await fixture.db.close();
      }
    },
  );
}
