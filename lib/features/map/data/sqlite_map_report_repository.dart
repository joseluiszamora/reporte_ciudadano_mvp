import '../../../core/database/app_database.dart';
import '../../../core/location/geo_point.dart';
import '../../reports/data/report_dao.dart';
import '../domain/map_report_repository.dart';

class SqliteMapReportRepository implements MapReportRepository {
  SqliteMapReportRepository(this.db);
  final AppDatabase db;
  @override
  Stream<List<MapReport>> watchMarkers() =>
      db.watchQuery({'reports', 'categories'}, () async {
        final rows = await db.customSelect('''SELECT r.id,r.title,r.latitude,r.longitude,r.status,r.is_demo,c.name AS category,c.icon_key
      FROM reports r JOIN categories c ON c.id=r.category_id
      WHERE r.deleted_at IS NULL ORDER BY r.created_at DESC,r.id''').get();
        return List.unmodifiable(
          rows.map(
            (row) => MapReport(
              id: row.read<String>('id'),
              title: row.read<String>('title'),
              category: row.read<String>('category'),
              categoryIcon: row.read<String>('icon_key'),
              point: GeoPoint(
                row.read<double>('latitude'),
                row.read<double>('longitude'),
              ),
              status: statusFromSql(row.read<String>('status')),
              isDemo: row.read<int>('is_demo') == 1,
            ),
          ),
        );
      });
}
