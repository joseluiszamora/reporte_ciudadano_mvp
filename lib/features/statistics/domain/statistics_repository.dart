class LocalStatistics {
  const LocalStatistics({
    required this.total,
    required this.reported,
    required this.inFollowUp,
    required this.resolved,
    required this.includesDemo,
  });
  final int total;
  final int reported;
  final int inFollowUp;
  final int resolved;
  final bool includesDemo;
}

abstract interface class StatisticsRepository {
  /// Excludes soft-deleted reports and demo unless explicitly requested.
  Stream<LocalStatistics> watch({
    DateTime? from,
    DateTime? to,
    bool includeDemo = false,
  });
}
