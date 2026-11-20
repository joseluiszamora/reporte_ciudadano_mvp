import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../map/presentation/map_canvas.dart';
import '../../map/presentation/map_tiles.dart';
import '../domain/report_read_repository.dart';
import 'report_labels.dart';
import 'report_photo.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.id,
    required this.repository,
    required this.photos,
    this.tiles = MapTiles.create,
  });
  final String id;
  final ReportReadRepository repository;
  final LocalPhotoReader photos;
  final TileProviderFactory tiles;
  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Stream<ReportView?> source = widget.repository.watchDetail(widget.id);
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle del reporte')),
    body: StreamBuilder<ReportView?>(
      stream: source,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar el reporte.'),
                TextButton(
                  onPressed: () => setState(
                    () => source = widget.repository.watchDetail(widget.id),
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final view = snapshot.data;
        if (view == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Este reporte no está disponible. Puede haber sido eliminado.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final report = view.details;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              report.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (report.isDemo)
              const Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('Reporte de demostración')),
              ),
            const SizedBox(height: 8),
            Text('Autor: ${report.publicAuthor}'),
            Text(view.category),
            Text('Estado: ${ReportLabels.status(report.status)}'),
            Text('Creado: ${ReportLabels.date(report.createdAt)}'),
            Text('Actualizado: ${ReportLabels.date(report.updatedAt)}'),
            if (report.resolvedAt != null)
              Text('Solucionado: ${ReportLabels.date(report.resolvedAt!)}'),
            Text(
              ReportLabels.elapsed(
                report.createdAt,
                report.resolvedAt,
                DateTime.now().toUtc(),
              ),
            ),
            const SizedBox(height: 16),
            if (view.photos.isEmpty)
              const Text('No hay fotografías disponibles.')
            else ...[
              Text(
                '${view.photos.length} fotografía(s). Desliza para verlas y toca para ampliar.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: PageView(
                  children: [
                    for (final photo in view.photos)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ReportPhoto(
                          path: photo.relativePath,
                          reader: widget.photos,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
            Text(report.description),
            const SizedBox(height: 20),
            Text('Ubicación', style: Theme.of(context).textTheme.titleMedium),
            if (report.addressLabel != null) Text(report.addressLabel!),
            SelectableText(
              '${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: MapCanvas(
                focus: GeoPoint(report.latitude, report.longitude),
                selected: GeoPoint(report.latitude, report.longitude),
                tiles: widget.tiles,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Historial y propuestas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (view.activity.isEmpty)
              const Text('No hay actividad registrada.')
            else
              for (final item in view.activity)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(ReportLabels.date(item.at)),
                        if (item.note != null) Text(item.note!),
                        if (item.demo) const Text('Validación de demostración'),
                        if (item.evidencePath != null)
                          SizedBox(
                            height: 180,
                            child: ReportPhoto(
                              path: item.evidencePath,
                              reader: widget.photos,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            const Text(
              'Datos y tiempos locales de este teléfono; no representan atención institucional verificada.',
            ),
          ],
        );
      },
    ),
  );
}
