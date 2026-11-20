import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/media/photo_storage.dart';
import '../domain/report_policy.dart';
import '../domain/report_repository.dart';

String statusToSql(ReportStatus status) => switch (status) {
  ReportStatus.reported => 'REPORTED',
  ReportStatus.inFollowUp => 'IN_FOLLOW_UP',
  ReportStatus.resolved => 'RESOLVED',
};

ReportStatus statusFromSql(String value) => switch (value) {
  'REPORTED' => ReportStatus.reported,
  'IN_FOLLOW_UP' => ReportStatus.inFollowUp,
  'RESOLVED' => ReportStatus.resolved,
  _ => throw StateError('Estado de reporte desconocido: $value'),
};

/// Private record for authorization. Not returned to public UI.
class LocalReportRow {
  LocalReportRow(this.row);
  final QueryRow row;
  String get authorUid => row.read<String>('author_uid');
  ReportStatus get status => statusFromSql(row.read<String>('status'));
  int get revision => row.read<int>('revision');
  bool get isDemo => row.read<int>('is_demo') == 1;

  ReportDetails publicDetails(List<StoredPhoto> photos) => ReportDetails(
    id: row.read<String>('id'),
    categoryId: row.read<String>('category_id'),
    title: row.read<String>('title'),
    description: row.read<String>('description'),
    latitude: row.read<double>('latitude'),
    longitude: row.read<double>('longitude'),
    addressLabel: row.readNullable<String>('address_label'),
    status: status,
    publicAuthor: row.read<String>('public_identity_mode') == 'ANONYMOUS'
        ? 'Ciudadano anónimo'
        : row.read<String>('public_name_snapshot'),
    photos: photos,
    createdAt: DateTime.parse(row.read<String>('created_at')),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
    resolvedAt: row.readNullable<String>('resolved_at') == null
        ? null
        : DateTime.parse(row.read<String>('resolved_at')),
    revision: revision,
    isDemo: isDemo,
  );
}

class ReportDao {
  ReportDao(this.db);
  final AppDatabase db;

  Future<LocalReportRow?> find(String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM reports WHERE id=? AND deleted_at IS NULL',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : LocalReportRow(row);
  }

  Future<List<StoredPhoto>> images(String id) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM report_images WHERE report_id=? ORDER BY sort_order',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows
        .map(
          (row) => StoredPhoto(
            relativePath: row.read<String>('local_relative_path'),
            mimeType: row.read<String>('mime_type'),
            bytes: row.read<int>('byte_size'),
          ),
        )
        .toList();
  }

  Future<List<ReportSummary>> list() async {
    final rows = await db
        .customSelect(
          'SELECT id,title,status,is_demo FROM reports WHERE deleted_at IS NULL ORDER BY created_at DESC,id',
        )
        .get();
    return List.unmodifiable(
      rows.map(
        (row) => ReportSummary(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          status: statusFromSql(row.read<String>('status')),
          isDemo: row.read<int>('is_demo') == 1,
        ),
      ),
    );
  }
}
