class StatisticsFilter {
  const StatisticsFilter({
    this.categoryId,
    this.from,
    this.until,
    this.includeDemo = false,
  });
  final String? categoryId;

  /// Inclusive instant of report creation; converted to UTC at the data boundary.
  final DateTime? from;

  /// Exclusive instant: midnight after the final selected local day.
  final DateTime? until;
  final bool includeDemo;
  bool get isActive =>
      categoryId != null || from != null || until != null || includeDemo;
}

class CategoryStatistics {
  const CategoryStatistics({
    required this.id,
    required this.name,
    required this.isActive,
    required this.total,
  });
  final String id;
  final String name;
  final bool isActive;
  final int total;
}

enum PendingAgeRange {
  underWeek('Menos de 7 días'),
  underMonth('De 7 a 29 días'),
  monthOrMore('30 días o más');

  const PendingAgeRange(this.label);
  final String label;

  static PendingAgeRange forDays(int days) => days < 7
      ? underWeek
      : days < 30
      ? underMonth
      : monthOrMore;
}

class StatisticsGroup {
  StatisticsGroup({
    required this.total,
    required this.reported,
    required this.inFollowUp,
    required this.resolved,
    required List<CategoryStatistics> categories,
    required this.averagePendingAge,
    required this.oldestPendingAge,
    required this.averageResolutionTime,
    Map<PendingAgeRange, int> pendingByAge = const {},
  }) : categories = List.unmodifiable(categories),
       pendingByAge = Map.unmodifiable(pendingByAge);
  final int total;
  final int reported;
  final int inFollowUp;
  final int resolved;
  int get pending => reported + inFollowUp;
  final List<CategoryStatistics> categories;
  final Map<PendingAgeRange, int> pendingByAge;

  /// Null means no sample, distinct from a measured zero duration.
  final Duration? averagePendingAge;
  final Duration? oldestPendingAge;

  /// Creation to latest resolution, only for reports currently resolved.
  final Duration? averageResolutionTime;
}

class LocalStatistics {
  const LocalStatistics({
    required this.local,
    required this.demo,
    required this.asOf,
  });
  final StatisticsGroup local;

  /// Present only when explicitly requested; never merged into local indicators.
  final StatisticsGroup? demo;
  final DateTime asOf;
}

abstract interface class StatisticsRepository {
  /// Public aggregates without author identifiers. Excludes deleted reports.
  /// Refreshes on data changes and periodically to update pending ages.
  Stream<LocalStatistics> watch(StatisticsFilter filter);
}
