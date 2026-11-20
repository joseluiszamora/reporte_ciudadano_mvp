import '../../../core/database/app_database.dart';
import '../../../core/database/local_session.dart';
import '../../reports/data/report_list_mapper.dart';
import '../../reports/data/report_query_dao.dart';
import '../../reports/domain/report_filter.dart';
import '../../reports/domain/report_read_repository.dart';
import '../domain/my_reports_repository.dart';

class SqliteMyReportsRepository implements MyReportsRepository {
  SqliteMyReportsRepository(this.db, this.session);
  final AppDatabase db;
  final LocalSession session;
  @override
  Stream<List<ReportListItem>> watchMine() => db.watchQuery(
    {'reports', 'categories', 'report_images', 'users'},
    () async {
      final actor = await session.requireUser();
      final rows = await ReportQueryDao(db)
          .rows(const ReportFilter(), authorUid: actor.uid);
      // Recheck a change of account while the asynchronous read was in progress.
      session.ensureCurrent(actor);
      return List.unmodifiable(rows.map(reportListItem));
    },
  );
}
