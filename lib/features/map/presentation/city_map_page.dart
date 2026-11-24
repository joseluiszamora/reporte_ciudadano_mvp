import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/civic_feedback.dart';
import '../../../core/location/geo_point.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../../core/location/location_gateway.dart';
import '../../reports/presentation/report_labels.dart';
import '../../reports/presentation/report_photo.dart';
import '../../reports/presentation/report_status_badge.dart';
import '../domain/map_report_repository.dart';
import 'location_controls.dart';
import 'location_cubit.dart';
import 'location_picker_page.dart';
import 'map_canvas.dart';
import 'map_tiles.dart';
import '../../categories/domain/category_repository.dart';
import '../../reports/domain/report_filter.dart';
import '../../reports/presentation/report_filter_cubit.dart';
import '../../reports/presentation/report_filter_bar.dart';

class CityMapPage extends StatefulWidget {
  const CityMapPage({
    super.key,
    required this.reports,
    required this.location,
    this.tiles = MapTiles.create,
    this.filters,
    this.categories,
    this.onOpenReport,
    this.photos,
  });
  final MapReportRepository reports;
  final LocationGateway location;
  final TileProviderFactory tiles;
  final ReportFilterCubit? filters;
  final CategoryRepository? categories;
  final ValueChanged<String>? onOpenReport;
  final LocalPhotoReader? photos;
  @override
  State<CityMapPage> createState() => _CityMapPageState();
}

class _CityMapPageState extends State<CityMapPage> {
  late final cubit = LocationCubit(widget.location);
  late final filters = widget.filters ?? ReportFilterCubit();
  ReportFilter? active;
  late Stream<List<MapReport>> markers;
  Stream<List<MapReport>> source(ReportFilter filter) {
    if (!identical(active, filter)) {
      active = filter;
      markers = widget.reports.watchMarkers(filter: filter);
    }
    return markers;
  }

  @override
  void dispose() {
    cubit.close();
    if (widget.filters == null) filters.close();
    super.dispose();
  }

  Future<void> choosePoint() async {
    final point = await Navigator.of(context, rootNavigator: true)
        .push<GeoPoint>(
          MaterialPageRoute(
            builder: (_) => LocationPickerPage(
              location: widget.location,
              initial: cubit.state.point,
              tiles: widget.tiles,
            ),
          ),
        );
    if (mounted && point != null) cubit.selectManual(point);
  }

  Future<void> showReport(MapReport report) async {
    final open = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (report.isDemo) ...[
                  const DemoBanner(),
                  const SizedBox(height: 12),
                ],
                if (report.photoPath != null && widget.photos != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ReportPhoto(
                        path: report.photoPath,
                        reader: widget.photos!,
                        expandable: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(report.category),
                Text(
                  report.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ReportStatusBadge(report.status),
                    if (report.createdAt case final created?)
                      Text(
                        ReportLabels.elapsed(
                          created,
                          report.resolvedAt,
                          DateTime.now(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(report.address ?? report.point.label),
                const SizedBox(height: 16),
                if (widget.onOpenReport != null)
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Ver detalle'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (open == true && mounted) widget.onOpenReport?.call(report.id);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ReportFilterCubit, ReportFilter>(
    bloc: filters,
    builder: (context, filter) => BlocBuilder<LocationCubit, LocationState>(
      bloc: cubit,
      builder: (context, location) => StreamBuilder<List<MapReport>>(
        stream: source(filter),
        builder: (context, snapshot) => LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (!keyboard)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Mapa de El Alto',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                IconButton(
                                  onPressed: choosePoint,
                                  tooltip: 'Elegir ubicación',
                                  icon: const Icon(
                                    Icons.edit_location_alt_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.categories != null)
                          ReportFilterBar(
                            filters: filters,
                            categories: widget.categories!,
                            quickFilters: true,
                          ),
                        if (!keyboard && snapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'No se pudieron cargar los reportes.',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => active = null),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          )
                        else if (!snapshot.hasData && !snapshot.hasError)
                          const LinearProgressIndicator()
                        else if (!keyboard && snapshot.data?.isEmpty == true)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Text(
                              filter.isActive
                                  ? 'No hay reportes que coincidan con los filtros.'
                                  : 'Aún no hay reportes locales en el mapa.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: MapCanvas(
                    focus: location.point,
                    focusRevision: location.focusRevision,
                    selected: location.point,
                    reports: snapshot.data ?? const [],
                    onReportTap: showReport,
                    tiles: widget.tiles,
                  ),
                ),
                if (!keyboard)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * .28,
                    ),
                    child: SingleChildScrollView(
                      child: LocationControls(cubit: cubit, state: location),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
