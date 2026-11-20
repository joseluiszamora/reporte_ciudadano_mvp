import '../../reports/domain/report_read_repository.dart';

abstract interface class MyReportsRepository {
  Stream<List<ReportListItem>> watchMine();
}
