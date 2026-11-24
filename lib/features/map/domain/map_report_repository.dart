import '../../../core/location/geo_point.dart';
import '../../reports/domain/report_policy.dart';
import '../../reports/domain/report_filter.dart';

class MapReport {
  const MapReport({
    required this.id,
    required this.title,
    required this.category,
    required this.point,
    required this.status,
    required this.isDemo,
    this.categoryIcon = 'category',
    this.createdAt,
    this.resolvedAt,
    this.photoPath,
    this.address,
  });
  final String id;
  final String title;
  final String category;
  final String categoryIcon;
  final GeoPoint point;
  final ReportStatus status;
  final bool isDemo;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? photoPath;
  final String? address;
}

abstract interface class MapReportRepository {
  Stream<List<MapReport>> watchMarkers({
    ReportFilter filter = const ReportFilter(),
  });
}
