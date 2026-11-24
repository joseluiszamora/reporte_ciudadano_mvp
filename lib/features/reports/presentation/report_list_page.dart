import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/civic_feedback.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../categories/domain/category_repository.dart';
import '../../categories/presentation/category_catalog.dart';
import '../domain/report_filter.dart';
import '../domain/report_read_repository.dart';
import 'report_filter_bar.dart';
import 'report_filter_cubit.dart';
import 'report_card.dart';

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
              const Expanded(child: Text('Datos locales de este dispositivo')),
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
                  child: SingleChildScrollView(
                    child: CivicState(
                      icon: Icons.error_outline_rounded,
                      title: 'No se pudieron cargar los reportes.',
                      action: OutlinedButton(
                        onPressed: retry,
                        child: const Text('Reintentar'),
                      ),
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData) {
                return const _ReportListLoading();
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    child: CivicState(
                      icon: filter.isActive
                          ? Icons.search_off_rounded
                          : Icons.list_alt_rounded,
                      title: filter.isActive
                          ? 'No hay reportes que coincidan con los filtros.'
                          : 'Todavía no hay reportes en este teléfono.',
                      action: OutlinedButton(
                        onPressed: filter.isActive
                            ? widget.filters.reset
                            : widget.onCreate,
                        child: Text(
                          filter.isActive ? 'Limpiar filtros' : 'Crear reporte',
                        ),
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = items[index];
                  return ReportCard(
                    report: report,
                    photos: widget.photos,
                    onOpen: () => widget.onOpen(report.id),
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

class _ReportListLoading extends StatelessWidget {
  const _ReportListLoading();

  @override
  Widget build(BuildContext context) {
    final shade = Theme.of(context).colorScheme.surfaceContainer;
    return Semantics(
      label: 'Cargando reportes',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 12, color: shade),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 18,
                    width: double.infinity,
                    child: ColoredBox(color: shade),
                  ),
                  const SizedBox(height: 12),
                  Container(width: 160, height: 24, color: shade),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
