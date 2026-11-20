import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/location/location_gateway.dart';
import '../../reports/domain/report_policy.dart';
import '../domain/map_report_repository.dart';
import 'location_controls.dart';
import 'location_cubit.dart';
import 'location_picker_page.dart';
import 'map_canvas.dart';
import 'map_tiles.dart';

class CityMapPage extends StatefulWidget {
  const CityMapPage({
    super.key,
    required this.reports,
    required this.location,
    this.tiles = MapTiles.create,
  });
  final MapReportRepository reports;
  final LocationGateway location;
  final TileProviderFactory tiles;
  @override
  State<CityMapPage> createState() => _CityMapPageState();
}

class _CityMapPageState extends State<CityMapPage> {
  late final cubit = LocationCubit(widget.location);
  late final markers = widget.reports.watchMarkers();
  @override
  void dispose() {
    cubit.close();
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

  void showReport(MapReport report) {
    final status = switch (report.status) {
      ReportStatus.reported => 'Reportado',
      ReportStatus.inFollowUp => 'En seguimiento',
      ReportStatus.resolved => 'Solucionado',
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(report.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(report.category),
              Text('Estado: $status'),
              Text('Coordenadas: ${report.point.label}'),
              if (report.isDemo) const Text('Reporte de demostración'),
              const SizedBox(height: 12),
              const Text('Datos locales de este teléfono.'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LocationCubit, LocationState>(
        bloc: cubit,
        builder: (context, location) => StreamBuilder<List<MapReport>>(
          stream: markers,
          builder: (context, snapshot) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mapa de El Alto',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: choosePoint,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Elegir ubicación'),
                    ),
                  ],
                ),
              ),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No se pudieron cargar los reportes locales. Vuelve a entrar al mapa para reintentar.',
                  ),
                ),
              if (snapshot.hasData && snapshot.data!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Aún no hay reportes locales en el mapa.'),
                ),
              Expanded(
                flex: 3,
                child: MapCanvas(
                  focus: location.point,
                  focusRevision: location.focusRevision,
                  selected: location.point,
                  reports: snapshot.data ?? const [],
                  onReportTap: showReport,
                  tiles: widget.tiles,
                ),
              ),
              Flexible(
                flex:
                    location.error != null ||
                        (location.point?.isFarFromElAlto ?? false)
                    ? 2
                    : 0,
                fit: FlexFit.tight,
                child: SingleChildScrollView(
                  child: LocationControls(cubit: cubit, state: location),
                ),
              ),
            ],
          ),
        ),
      );
}
