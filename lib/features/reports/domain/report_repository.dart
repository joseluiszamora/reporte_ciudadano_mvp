import 'report_policy.dart';
import '../../../core/media/photo_storage.dart';

class ReportDraft {
  ReportDraft({
    required this.categoryId,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.identityMode,
    required List<StoredPhoto> photos,
    this.addressLabel,
    this.requestId,
  }) : photos = List.unmodifiable(photos);
  final String categoryId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final PublicIdentityMode identityMode;
  final List<StoredPhoto> photos;
  final String? addressLabel;
  final String? requestId;
}

/// Public projection: never carries UID, email or Google photo URL.
class ReportDetails {
  ReportDetails({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.publicAuthor,
    required List<StoredPhoto> photos,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.isDemo,
    this.resolvedAt,
    this.addressLabel,
  }) : photos = List.unmodifiable(photos);
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String? addressLabel;
  final ReportStatus status;
  final String publicAuthor;
  final List<StoredPhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final int revision;
  final bool isDemo;
}

class ReportSummary {
  const ReportSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.isDemo,
  });
  final String id;
  final String title;
  final ReportStatus status;
  final bool isDemo;
}

abstract interface class ReportRepository {
  Stream<List<ReportSummary>> watchReports();
  Future<ReportDetails?> getReport(String id);
  Future<String> create(ReportDraft draft);
  Future<void> update({
    required String reportId,
    required ReportDraft draft,
    required int expectedRevision,
    required String reason,
  });
  Future<void> softDelete({required String reportId, required String reason});
}
