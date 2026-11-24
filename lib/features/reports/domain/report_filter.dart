import 'report_policy.dart';

enum ReportOrder { newest, oldest, longestPending }

class ReportFilter {
  const ReportFilter({
    this.search = '',
    this.categoryId,
    this.status,
    this.from,
    this.until,
    this.order = ReportOrder.newest,
  });
  final String search;
  final String? categoryId;
  final ReportStatus? status;

  /// Inclusive UTC instant. UI converts the selected local date to UTC.
  final DateTime? from;

  /// Exclusive UTC instant: midnight after the final local day.
  final DateTime? until;
  final ReportOrder order;
  bool get isActive =>
      search.trim().isNotEmpty ||
      categoryId != null ||
      status != null ||
      from != null ||
      until != null ||
      order != ReportOrder.newest;
  ReportFilter withSearch(String text) => ReportFilter(
    search: text,
    categoryId: categoryId,
    status: status,
    from: from,
    until: until,
    order: order,
  );
}
