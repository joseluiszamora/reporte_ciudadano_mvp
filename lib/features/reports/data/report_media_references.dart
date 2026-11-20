import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class ReportMediaReferences {
  ReportMediaReferences(this.db);
  final AppDatabase db;
  Future<bool> contains(String path) async {
    final rows = await db
        .customSelect(
          '''SELECT 1 FROM report_images WHERE local_relative_path=?
      UNION ALL SELECT 1 FROM resolution_proposals WHERE evidence_image_path=? LIMIT 1''',
          variables: [Variable.withString(path), Variable.withString(path)],
        )
        .get();
    if (rows.isNotEmpty) return true;
    for (final row
        in await db
            .customSelect('SELECT snapshot_json FROM report_revisions')
            .get()) {
      final data =
          jsonDecode(row.read<String>('snapshot_json')) as Map<String, dynamic>;
      if ((data['images'] as List<dynamic>).any(
        (image) => image['local_relative_path'] == path,
      )) {
        return true;
      }
    }
    return false;
  }
}
