import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../map/presentation/map_canvas.dart';
import '../../map/presentation/map_tiles.dart';
import '../domain/report_read_repository.dart';
import 'report_labels.dart';
import 'report_photo.dart';
import 'report_share.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.id,
    required this.repository,
    required this.photos,
    this.tiles = MapTiles.create,
    this.onManage,
  });
  final String id;
  final ReportReadRepository repository;
  final LocalPhotoReader photos;
  final TileProviderFactory tiles;
  final VoidCallback? onManage;
  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Stream<ReportView?> source = widget.repository.watchDetail(widget.id);
  late final Timer timer;
  final photoController = PageController();

  Future<void> share(ReportView view) async {
    final summary = ReportShare.summary(view);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartir resumen'),
        content: SingleChildScrollView(child: SelectableText(summary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      final current = await widget.repository.watchDetail(widget.id).first;
      if (!mounted) return;
      if (current == null || ReportShare.summary(current) != summary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El reporte cambió o ya no está disponible. Revisa el detalle.',
            ),
          ),
        );
        return;
      }
      await ReportShare.send(summary);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo compartir. Abre el resumen para copiar el texto.',
            ),
          ),
        );
      }
    }
  }

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
    photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle del reporte'),
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/reportes');
          }
        },
      ),
    ),
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
            OutlinedButton.icon(
              onPressed: () => share(view),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir resumen'),
            ),
            if (widget.onManage != null)
              OutlinedButton.icon(
                onPressed: widget.onManage,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Acciones y propuestas'),
              ),
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
                '${view.photos.length} fotografía(s). Toca una fotografía para ampliarla.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: PageView(
                  controller: photoController,
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
              if (view.photos.length > 1)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => photoController.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Foto anterior'),
                    ),
                    TextButton(
                      onPressed: () => photoController.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Foto siguiente'),
                    ),
                  ],
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
