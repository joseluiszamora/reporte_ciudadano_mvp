import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/report_filter.dart';

class ReportFilterCubit extends Cubit<ReportFilter> {
  ReportFilterCubit() : super(const ReportFilter());
  void search(String text) => emit(state.withSearch(text));
  void apply(ReportFilter filter) => emit(filter);
  void reset() => emit(const ReportFilter());
}
