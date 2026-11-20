import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/media/local_photo_reader.dart';
import '../../categories/domain/category_repository.dart';
import '../../categories/presentation/category_catalog.dart';
import '../domain/report_filter.dart';
import '../domain/report_read_repository.dart';
import 'report_filter_bar.dart';
import 'report_filter_cubit.dart';
import 'report_labels.dart';
import 'report_photo.dart';

class ReportListPage extends StatefulWidget {
  const ReportListPage({
    super.key,
    required this.repository,
    required this.filters,
    required this.categories,
    required this.photos,
    required this.onOpen,
    required this.onCreate,
  });
  final ReportReadRepository repository;
  final ReportFilterCubit filters;
  final CategoryRepository categories;
  final LocalPhotoReader photos;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;
  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  ReportFilter? active;
  late Stream<List<ReportListItem>> reports;
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

  Stream<List<ReportListItem>> source(ReportFilter filter) {
    if (!identical(active, filter)) {
      active = filter;
      reports = widget.repository.watchList(filter);
    }
    return reports;
  }

  void retry() => setState(() {
    active = null;
  });
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ReportFilterCubit, ReportFilter>(
    bloc: widget.filters,
    builder: (context, filter) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Reportes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => CategoryCatalog(
                    categories: widget.categories.watchCategories(),
                  ),
                ),
                child: const Text('Ver categorías'),
              ),
            ],
          ),
        ),
        ReportFilterBar(filters: widget.filters, categories: widget.categories),
        Expanded(
          child: StreamBuilder<List<ReportListItem>>(
            stream: source(filter),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar los reportes.'),
                      TextButton(
                        onPressed: retry,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.description_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          filter.isActive
                              ? 'No hay reportes que coincidan con los filtros.'
                              : 'Todavía no hay reportes en este teléfono.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: filter.isActive
                              ? widget.filters.reset
                              : widget.onCreate,
                          child: Text(
                            filter.isActive
                                ? 'Limpiar filtros'
                                : 'Crear reporte',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final report = items[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => widget.onOpen(report.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: ReportPhoto(
                              path: report.photoPath,
                              reader: widget.photos,
                              expandable: false,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(report.category),
                                Text(
                                  'Estado: ${ReportLabels.status(report.status)}',
                                ),
                                Text(
                                  report.address ??
                                      '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                                ),
                                Text(
                                  ReportLabels.elapsed(
                                    report.createdAt,
                                    report.resolvedAt,
                                    DateTime.now().toUtc(),
                                  ),
                                ),
                                Text(
                                  'Creado: ${ReportLabels.date(report.createdAt)}',
                                ),
                                if (report.isDemo)
                                  const Chip(label: Text('Demostración')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
