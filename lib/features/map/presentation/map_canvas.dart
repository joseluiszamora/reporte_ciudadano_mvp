import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/geo_point.dart';
import '../../reports/domain/report_policy.dart';
import '../domain/map_report_repository.dart';
import 'map_tiles.dart';

class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    this.focus,
    this.focusRevision = 0,
    this.selected,
    this.onSelect,
    this.reports = const [],
    this.onReportTap,
    this.tiles = MapTiles.create,
  });
  final GeoPoint? focus;
  final int focusRevision;
  final GeoPoint? selected;
  final ValueChanged<GeoPoint>? onSelect;
  final List<MapReport> reports;
  final ValueChanged<MapReport>? onReportTap;
  final TileProviderFactory tiles;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  final controller = MapController();
  late TileProvider provider;
  bool ready = false;
  bool tileError = false;
  bool errorQueued = false;
  int generation = 0;

  LatLng mapPoint(GeoPoint point) =>
      LatLng(point.latitude.clamp(-85.05112878, 85.05112878), point.longitude);

  @override
  void initState() {
    super.initState();
    provider = widget.tiles();
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focus != null &&
        (widget.focus != oldWidget.focus ||
            widget.focusRevision != oldWidget.focusRevision)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ready) controller.move(mapPoint(widget.focus!), 16);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void failedTile(int attempt) {
    if (!mounted || tileError || errorQueued || attempt != generation) return;
    errorQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      errorQueued = false;
      if (mounted && attempt == generation) setState(() => tileError = true);
    });
  }

  void retry() => setState(() {
    generation++;
    tileError = false;
    // TileLayer disposes its previous provider when its key changes.
    provider = widget.tiles();
  });

  Future<void> attribution() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Show a recoverable message below. */
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir la atribución. Revisa tu conexión y vuelve a intentarlo.',
          ),
        ),
      );
    }
  }

  Color markerColor(ReportStatus status) => switch (status) {
    ReportStatus.reported => const Color(0xFFB3261E),
    ReportStatus.inFollowUp => const Color(0xFF875500),
    ReportStatus.resolved => const Color(0xFF176B64),
  };

  String statusLabel(ReportStatus status) => switch (status) {
    ReportStatus.reported => 'Reportado',
    ReportStatus.inFollowUp => 'En seguimiento',
    ReportStatus.resolved => 'Solucionado',
  };

  IconData categoryIcon(String key) => switch (key) {
    'road' => Icons.construction,
    'traffic' => Icons.traffic,
    'walk' => Icons.directions_walk,
    'light' => Icons.lightbulb_outline,
    'delete' => Icons.delete_outline,
    'water' => Icons.water_drop_outlined,
    'sign' => Icons.signpost_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final attempt = generation;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                key: const ValueKey('city-map'),
                mapController: controller,
                options: MapOptions(
                  initialCenter: mapPoint(widget.focus ?? GeoPoint.elAlto),
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () => ready = true,
                  onTap: widget.onSelect == null
                      ? null
                      : (_, point) => widget.onSelect!(
                          GeoPoint(
                            point.latitude.clamp(-90, 90),
                            ((point.longitude + 180) % 360) - 180,
                          ),
                        ),
                ),
                children: [
                  TileLayer(
                    key: ValueKey(generation),
                    urlTemplate: MapTiles.url,
                    userAgentPackageName: 'bo.elalto.reporte_ciudadano_mvp',
                    tileProvider: provider,
                    maxNativeZoom: 19,
                    panBuffer: 0,
                    keepBuffer: 1,
                    errorTileCallback: (_, _, _) => failedTile(attempt),
                    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                  ),
                  MarkerLayer(
                    markers: [
                      for (final report in widget.reports)
                        Marker(
                          point: mapPoint(report.point),
                          width: 48,
                          height: 48,
                          child: IconButton(
                            tooltip:
                                '${report.title} · ${report.category} · ${statusLabel(report.status)}${report.isDemo ? ' · Demostración' : ''}',
                            onPressed: () => widget.onReportTap?.call(report),
                            padding: EdgeInsets.zero,
                            icon: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 44,
                                  color: markerColor(report.status),
                                ),
                                Positioned(
                                  top: 8,
                                  child: Icon(
                                    categoryIcon(report.categoryIcon),
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.selected != null)
                        Marker(
                          point: mapPoint(widget.selected!),
                          width: 48,
                          height: 48,
                          child: const Tooltip(
                            message: 'Ubicación elegida',
                            child: Icon(
                              Icons.place,
                              size: 44,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Acercar mapa',
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (ready) {
                            controller.move(
                              controller.camera.center,
                              (controller.camera.zoom + 1).clamp(3, 19),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Alejar mapa',
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (ready) {
                            controller.move(
                              controller.camera.center,
                              (controller.camera.zoom - 1).clamp(3, 19),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Centrar en El Alto',
                        icon: const Icon(Icons.location_city_outlined),
                        onPressed: () {
                          if (ready) {
                            controller.move(mapPoint(GeoPoint.elAlto), 13);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: attribution,
                      child: const Text('© OpenStreetMap contributors'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (tileError)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'No se pudo cargar parte del mapa. Puedes seguir eligiendo coordenadas y consultar los datos locales.',
                    ),
                  ),
                  TextButton(onPressed: retry, child: const Text('Reintentar')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
