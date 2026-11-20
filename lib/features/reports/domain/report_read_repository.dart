import '../../../core/media/photo_storage.dart';
import 'report_filter.dart';
import 'report_policy.dart';
import 'report_repository.dart';

class ReportListItem {
  const ReportListItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.isDemo,
    required this.latitude,
    required this.longitude,
    this.address,
    this.photoPath,
    this.resolvedAt,
  });
  final String id;
  final String title;
  final String category;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool isDemo;
  final double latitude;
  final double longitude;
  final String? address;
  final String? photoPath;
}

class PublicReportActivity {
  const PublicReportActivity({
    required this.at,
    required this.text,
    this.note,
    this.demo = false,
    this.evidencePath,
  });
  final DateTime at;
  final String text;
  final String? note;
  final bool demo;
  final String? evidencePath;
}

class ReportView {
  ReportView({
    required this.details,
    required this.category,
    required List<PublicReportActivity> activity,
  }) : activity = List.unmodifiable(activity);
  final ReportDetails details;
  final String category;
  final List<PublicReportActivity> activity;
  List<StoredPhoto> get photos => details.photos;
}

abstract interface class ReportReadRepository {
  Stream<List<ReportListItem>> watchList(ReportFilter filter);
  Stream<ReportView?> watchDetail(String id);
}
