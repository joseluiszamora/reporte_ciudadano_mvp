import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/report_filter.dart';
import 'report_dao.dart';

/// The shared query for map and list. Never selects private author identifiers.
class ReportQueryDao {
  ReportQueryDao(this.db);
  final AppDatabase db;
  Future<List<QueryRow>> rows(ReportFilter filter) async {
    final where = <String>['r.deleted_at IS NULL'];
    final variables = <Variable>[];
    if (filter.categoryId != null) {
      where.add('r.category_id=?');
      variables.add(Variable.withString(filter.categoryId!));
    }
    if (filter.status != null) {
      where.add('r.status=?');
      variables.add(Variable.withString(statusToSql(filter.status!)));
    }
    if (filter.from != null) {
      where.add('r.created_at>=?');
      variables.add(
        Variable.withString(filter.from!.toUtc().toIso8601String()),
      );
    }
    if (filter.until != null) {
      where.add('r.created_at<?');
      variables.add(
        Variable.withString(filter.until!.toUtc().toIso8601String()),
      );
    }
    final direction = filter.order == ReportOrder.newest ? 'DESC' : 'ASC';
    final rows = await db.customSelect(
      '''SELECT r.id,r.title,r.description,r.latitude,r.longitude,r.address_label,
      r.status,r.created_at,r.resolved_at,r.is_demo,c.name AS category,c.icon_key,
      (SELECT local_relative_path FROM report_images i WHERE i.report_id=r.id ORDER BY sort_order LIMIT 1) AS photo_path
      FROM reports r JOIN categories c ON c.id=r.category_id WHERE ${where.join(' AND ')}
      ORDER BY r.created_at $direction,r.id $direction''',
      variables: variables,
    ).get();
    final query = filter.search.trim().toLowerCase();
    // Dart case folding handles Spanish uppercase characters that SQLite LIKE
    // does not. Search is literal: % and _ are not SQL wildcards.
    return query.isEmpty
        ? rows
        : rows
              .where(
                (row) =>
                    row.read<String>('title').toLowerCase().contains(query) ||
                    row
                        .read<String>('description')
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
  }
}
