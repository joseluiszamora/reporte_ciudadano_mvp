import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/report_filter.dart';
import '../domain/report_read_repository.dart';
import 'report_dao.dart';
import 'report_query_dao.dart';

String publicStatus(String status) => switch (status) {
  'REPORTED' => 'Reportado',
  'IN_FOLLOW_UP' => 'En seguimiento',
  'RESOLVED' => 'Solucionado',
  _ => 'Estado desconocido',
};

class SqliteReportReadRepository implements ReportReadRepository {
  SqliteReportReadRepository(this.db);
  final AppDatabase db;
  @override
  Stream<List<ReportListItem>> watchList(ReportFilter filter) =>
      db.watchQuery({'reports', 'categories', 'report_images'}, () async {
        final rows = await ReportQueryDao(db).rows(filter);
        return List.unmodifiable(
          rows.map(
            (row) => ReportListItem(
              id: row.read<String>('id'),
              title: row.read<String>('title'),
              category: row.read<String>('category'),
              status: statusFromSql(row.read<String>('status')),
              createdAt: DateTime.parse(row.read<String>('created_at')),
              isDemo: row.read<int>('is_demo') == 1,
              latitude: row.read<double>('latitude'),
              longitude: row.read<double>('longitude'),
              address: row.readNullable<String>('address_label'),
              photoPath: row.readNullable<String>('photo_path'),
              resolvedAt: row.readNullable<String>('resolved_at') == null
                  ? null
                  : DateTime.parse(row.read<String>('resolved_at')),
            ),
          ),
        );
      });

  @override
  Stream<ReportView?> watchDetail(String id) => db.watchQuery(
    {
      'reports',
      'categories',
      'report_images',
      'report_status_history',
      'resolution_proposals',
    },
    () => db.transaction(() async {
      final dao = ReportDao(db);
      final row = await dao.find(id);
      if (row == null) return null;
      final details = row.publicDetails(await dao.images(id));
      final category = await db
          .customSelect(
            'SELECT name FROM categories WHERE id=?',
            variables: [Variable.withString(details.categoryId)],
          )
          .getSingle();
      final history = await db
          .customSelect(
            '''SELECT from_status,to_status,note,created_at,is_demo_action FROM report_status_history
        WHERE report_id=? ORDER BY created_at,id''',
            variables: [Variable.withString(id)],
          )
          .get();
      final proposals = await db
          .customSelect(
            '''SELECT note,status,evidence_image_path,created_at,reviewed_at,review_note,is_demo_review
        FROM resolution_proposals WHERE report_id=? ORDER BY created_at,id''',
            variables: [Variable.withString(id)],
          )
          .get();
      final activity = <PublicReportActivity>[
        for (final event in history)
          PublicReportActivity(
            at: DateTime.parse(event.read<String>('created_at')),
            text: event.readNullable<String>('from_status') == null
                ? 'Reporte creado'
                : 'Estado: ${publicStatus(event.read<String>('to_status'))}',
            note: event.readNullable<String>('note'),
            demo: event.read<int>('is_demo_action') == 1,
          ),
        for (final proposal in proposals) ...[
          PublicReportActivity(
            at: DateTime.parse(proposal.read<String>('created_at')),
            text: 'Solución propuesta',
            note: proposal.read<String>('note'),
            evidencePath: proposal.read<String>('evidence_image_path'),
          ),
          if (proposal.readNullable<String>('reviewed_at') != null)
            PublicReportActivity(
              at: DateTime.parse(proposal.read<String>('reviewed_at')),
              text: proposal.read<String>('status') == 'APPROVED'
                  ? 'Propuesta aprobada'
                  : 'Propuesta rechazada',
              note: proposal.readNullable<String>('review_note'),
              demo: proposal.read<int>('is_demo_review') == 1,
            ),
        ],
      ]..sort((a, b) => a.at.compareTo(b.at));
      return ReportView(
        details: details,
        category: category.read<String>('name'),
        activity: activity,
      );
    }),
  );
}
