import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/geo_point.dart';
import '../../categories/presentation/category_icon.dart';
import '../../reports/presentation/report_labels.dart';
import '../../reports/presentation/report_status_badge.dart';
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
  int zoom = 13;
  bool draggingPin = false;
  Offset? dragOffset;

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

  List<Marker> reportMarkers(BuildContext context) {
    if (widget.reports.isEmpty) return const [];
    final groups = <(int, int), List<MapReport>>{};
    // Web Mercator gives stable clusters while panning a given zoom level.
    final world = 256 * math.pow(2, zoom);
    for (final report in widget.reports) {
      final point = mapPoint(report.point);
      final latitude = point.latitude * math.pi / 180;
      final sinLatitude = math.sin(latitude);
      final x = (point.longitude + 180) / 360 * world;
      final y =
          (.5 -
              math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) *
          world;
      (groups[((x / 52).floor(), (y / 52).floor())] ??= []).add(report);
    }

    return [
      for (final group in groups.values)
        Marker(
          point: mapPoint(group.first.point),
          width: 48,
          height: 48,
          child: group.length == 1
              ? reportPin(context, group.single)
              : clusterPin(context, group),
        ),
    ];
  }

  Widget reportPin(BuildContext context, MapReport report) {
    final scheme = Theme.of(context).colorScheme;
    final colors = report.status.colors(context);
    return IconButton(
      tooltip:
          '${report.title} · ${report.category} · ${ReportLabels.status(report.status)}${report.isDemo ? ' · Demostración' : ''}',
      onPressed: widget.onReportTap == null
          ? null
          : () => widget.onReportTap!(report),
      padding: EdgeInsets.zero,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.location_on_rounded, size: 48, color: scheme.onSurface),
          Icon(Icons.location_on_rounded, size: 43, color: colors.foreground),
          Positioned(
            top: 10,
            child: Icon(
              categoryIcon(report.categoryIcon),
              size: 17,
              color: colors.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget clusterPin(BuildContext context, List<MapReport> group) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: '${group.length} reportes agrupados',
      onPressed: () => openCluster(group),
      padding: EdgeInsets.zero,
      icon: Container(
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 2),
        ),
        alignment: Alignment.center,
        width: 44,
        height: 44,
        child: Text(
          group.length > 999 ? '999+' : '${group.length}',
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> openCluster(List<MapReport> group) async {
    if (!ready) return;
    final point = mapPoint(group.first.point);
    if (zoom < 19 && group.any((report) => report.point != group.first.point)) {
      controller.move(point, (zoom + 2).clamp(3, 19).toDouble());
      return;
    }
    final selected = await showModalBottomSheet<MapReport>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: group.length,
          itemBuilder: (context, index) {
            final report = group[index];
            return ListTile(
              leading: Icon(categoryIcon(report.categoryIcon)),
              title: Text(report.title),
              subtitle: Text(ReportLabels.status(report.status)),
              onTap: () => Navigator.pop(context, report),
            );
          },
        ),
      ),
    );
    if (mounted && selected != null) widget.onReportTap?.call(selected);
  }

  void finishDrag() {
    final offset = dragOffset;
    if (offset != null && ready && widget.selected != null) {
      final camera = controller.camera;
      final pixel = camera.latLngToScreenOffset(mapPoint(widget.selected!));
      final point = camera.screenOffsetToLatLng(pixel + offset);
      widget.onSelect?.call(
        GeoPoint(
          point.latitude.clamp(-90, 90),
          ((point.longitude + 180) % 360) - 180,
        ),
      );
    }
    setState(() {
      dragOffset = null;
      draggingPin = false;
    });
  }

  Widget selectedPin(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pin = Tooltip(
      message: widget.onSelect == null
          ? 'Ubicación elegida'
          : 'Arrastra para ajustar la ubicación',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.place_rounded, size: 48, color: scheme.onSurface),
          Icon(Icons.place_rounded, size: 43, color: scheme.primary),
        ],
      ),
    );
    if (widget.onSelect == null) return pin;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => setState(() {
        draggingPin = true;
        dragOffset = Offset.zero;
      }),
      onPanUpdate: (event) => setState(
        () => dragOffset = (dragOffset ?? Offset.zero) + event.delta,
      ),
      onPanEnd: (_) => finishDrag(),
      onPanCancel: () => setState(() {
        dragOffset = null;
        draggingPin = false;
      }),
      child: Transform.translate(offset: dragOffset ?? Offset.zero, child: pin),
    );
  }

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
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainer,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: InteractionOptions(
                    flags: draggingPin
                        ? InteractiveFlag.none
                        : InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () => ready = true,
                  onPositionChanged: (camera, _) {
                    final level = camera.zoom.floor();
                    if (level != zoom) setState(() => zoom = level);
                  },
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
                    userAgentPackageName: 'com.mvp.reporte_ciudadano_mvp',
                    tileProvider: provider,
                    maxNativeZoom: 19,
                    panBuffer: 0,
                    keepBuffer: 1,
                    errorTileCallback: (_, _, _) => failedTile(attempt),
                    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                  ),
                  MarkerLayer(
                    markers: [
                      ...reportMarkers(context),
                      if (widget.selected != null)
                        Marker(
                          point: mapPoint(widget.selected!),
                          width: 48,
                          height: 48,
                          child: selectedPin(context),
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
