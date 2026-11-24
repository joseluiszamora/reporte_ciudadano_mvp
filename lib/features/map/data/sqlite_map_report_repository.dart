import '../../../core/database/app_database.dart';
import '../../../core/location/geo_point.dart';
import '../../reports/data/report_dao.dart';
import '../../reports/data/report_query_dao.dart';
import '../../reports/domain/report_filter.dart';
import '../domain/map_report_repository.dart';

class SqliteMapReportRepository implements MapReportRepository {
  SqliteMapReportRepository(this.db);
  final AppDatabase db;
  @override
  Stream<List<MapReport>> watchMarkers({
    ReportFilter filter = const ReportFilter(),
  }) => db.watchQuery({'reports', 'categories', 'report_images'}, () async {
    final rows = await ReportQueryDao(db).rows(filter);
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
          createdAt: DateTime.parse(row.read<String>('created_at')),
          resolvedAt: DateTime.tryParse(
            row.readNullable<String>('resolved_at') ?? '',
          ),
          photoPath: row.readNullable<String>('photo_path'),
          address: row.readNullable<String>('address_label'),
        ),
      ),
    );
  });
}
