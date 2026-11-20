import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/statistics_repository.dart';

/// App-scoped and independent of map/list filters. Resets when the app restarts.
class StatisticsFilterCubit extends Cubit<StatisticsFilter> {
  StatisticsFilterCubit() : super(const StatisticsFilter());
  void category(String? id) => emit(
    StatisticsFilter(
      categoryId: id,
      from: state.from,
      until: state.until,
      includeDemo: state.includeDemo,
    ),
  );
  void dates(DateTime? from, DateTime? until) => emit(
    StatisticsFilter(
      categoryId: state.categoryId,
      from: from,
      until: until,
      includeDemo: state.includeDemo,
    ),
  );
  void demo(bool enabled) => emit(
    StatisticsFilter(
      categoryId: state.categoryId,
      from: state.from,
      until: state.until,
      includeDemo: enabled,
    ),
  );
  void reset() => emit(const StatisticsFilter());
}
