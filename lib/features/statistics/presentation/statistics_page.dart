import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/civic_feedback.dart';
import '../../reports/domain/report_policy.dart';
import '../../reports/presentation/report_status_badge.dart';

import '../../categories/domain/category_repository.dart';
import '../../reports/presentation/report_labels.dart';
import '../domain/statistics_repository.dart';
import 'statistics_filter_cubit.dart';

String statisticsDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays} ${duration.inDays == 1 ? 'día' : 'días'} ${duration.inHours % 24} h';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours} h ${duration.inMinutes % 60} min';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes} min';
  return duration == Duration.zero ? '0 min' : 'Menos de 1 min';
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.repository,
    required this.categories,
    required this.filters,
    required this.onCreate,
  });
  final StatisticsRepository repository;
  final CategoryRepository categories;
  final StatisticsFilterCubit filters;
  final VoidCallback onCreate;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Stream<LocalStatistics> statistics = widget.repository.watch(
    widget.filters.state,
  );
  late Stream<List<ReportCategory>> categories = widget.categories
      .watchCategories();
  bool choosingDates = false;
  String dateLabel(StatisticsFilter filter) {
    final start = filter.from == null
        ? null
        : ReportLabels.date(filter.from!, time: false);
    final end = filter.until == null
        ? null
        : ReportLabels.date(
            filter.until!.subtract(const Duration(microseconds: 1)),
            time: false,
          );
    if (start != null && end != null) return '$start — $end';
    if (start != null) return 'Desde $start';
    if (end != null) return 'Hasta $end';
    return 'Elegir fechas de creación';
  }

  Future<void> dates() async {
    if (choosingDates) return;
    choosingDates = true;
    try {
      final filter = widget.filters.state;
      final last = filter.until?.toLocal();
      final range = await showDateRangePicker(
        context: context,
        confirmText: 'Aplicar fechas',
        saveText: 'Aplicar fechas',
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        initialDateRange: filter.from == null || last == null
            ? null
            : DateTimeRange(
                start: filter.from!.toLocal(),
                end: DateTime(last.year, last.month, last.day - 1),
              ),
      );
      if (range != null && mounted) {
        widget.filters.dates(
          DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          ).toUtc(),
          DateTime(range.end.year, range.end.month, range.end.day + 1).toUtc(),
        );
      }
    } finally {
      choosingDates = false;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<StatisticsFilterCubit, StatisticsFilter>(
    bloc: widget.filters,
    listener: (_, filter) => setState(() {
      statistics = widget.repository.watch(filter);
    }),
    builder: (context, filter) => StreamBuilder<List<ReportCategory>>(
      stream: categories,
      builder: (context, categorySnapshot) => StreamBuilder<LocalStatistics>(
        stream: statistics,
        builder: (context, statisticsSnapshot) => ListView(
          key: const PageStorageKey('statistics-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            const CivicNotice(
              icon: Icons.smartphone_rounded,
              text: 'Datos locales de este dispositivo',
            ),
            const SizedBox(height: 8),
            const Text('Estadísticas locales; no representan a toda la ciudad'),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final snapshot = categorySnapshot;
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No se pudieron cargar las categorías.'),
                      TextButton(
                        onPressed: () => setState(() {
                          categories = widget.categories.watchCategories();
                        }),
                        child: const Text('Reintentar categorías'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final options = snapshot.data!;
                return DropdownButtonFormField<String>(
                  key: ValueKey(filter.categoryId),
                  initialValue: filter.categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría de estadísticas',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    if (filter.categoryId != null &&
                        !options.any((item) => item.id == filter.categoryId))
                      DropdownMenuItem(
                        value: filter.categoryId,
                        child: const Text('Categoría no disponible'),
                      ),
                    for (final item in options)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          '${item.name}${item.isActive ? '' : ' (inactiva)'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: widget.filters.category,
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: dates,
                  icon: const Icon(Icons.date_range),
                  label: Text(dateLabel(filter)),
                ),
                if (filter.from != null || filter.until != null)
                  TextButton(
                    onPressed: () => widget.filters.dates(null, null),
                    child: const Text('Quitar fechas'),
                  ),
              ],
            ),
            const Text(
              'El período filtra la fecha de creación, no la fecha de solución. Estos filtros son independientes del mapa y la lista.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir demostración'),
              subtitle: const Text(
                'Se muestra por separado, sin mezclar conteos ni promedios.',
              ),
              value: filter.includeDemo,
              onChanged: widget.filters.demo,
            ),
            if (filter.isActive)
              TextButton.icon(
                onPressed: widget.filters.reset,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpiar filtros de estadísticas'),
              ),
            Builder(
              builder: (context) {
                final snapshot = statisticsSnapshot;
                // Never label results from the previous filter as if they were current.
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text(
                        'No se pudieron calcular las estadísticas. Revisa los filtros o vuelve a intentarlo.',
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          statistics = widget.repository.watch(
                            widget.filters.state,
                          );
                        }),
                        child: const Text('Reintentar estadísticas'),
                      ),
                    ],
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Text('No hay indicadores disponibles.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Actualizado: ${ReportLabels.date(data.asOf)}'),
                    _StatisticsGroupView(
                      group: data.local,
                      demo: false,
                      onCreate: widget.onCreate,
                    ),
                    if (data.demo != null) ...[
                      const SizedBox(height: 20),
                      const DemoBanner(),
                      const SizedBox(height: 8),
                      const Text(
                        'Los ejemplos y su revisión simulada se muestran por separado.',
                      ),
                      _StatisticsGroupView(group: data.demo!, demo: true),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatisticsGroupView extends StatelessWidget {
  const _StatisticsGroupView({
    required this.group,
    required this.demo,
    this.onCreate,
  });
  final StatisticsGroup group;
  final bool demo;
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      Text(
        demo ? 'Demostración' : 'Reportes locales',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700
              ? 4
              : constraints.maxWidth >= 300
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in [
                (label: 'Total', value: group.total, status: null),
                (
                  label: 'Reportados',
                  value: group.reported,
                  status: ReportStatus.reported,
                ),
                (
                  label: 'En seguimiento',
                  value: group.inFollowUp,
                  status: ReportStatus.inFollowUp,
                ),
                (
                  label: 'Solucionados',
                  value: group.resolved,
                  status: ReportStatus.resolved,
                ),
              ])
                SizedBox(
                  width: width,
                  child: Card(
                    key: ValueKey('${demo ? 'demo' : 'local'}:${metric.label}'),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            metric.status?.icon ?? Icons.bar_chart_rounded,
                            color:
                                metric.status?.colors(context).foreground ??
                                Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(metric.label),
                          Text(
                            '${metric.value}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      if (group.total == 0) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            demo
                ? 'Sin reportes de demostración para estos filtros.'
                : 'No hay reportes locales para estos filtros.',
          ),
        ),
        if (onCreate != null)
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Crear reporte'),
          ),
      ] else ...[
        const SizedBox(height: 16),
        Text('Tiempos', style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Antigüedad media de pendientes'),
          subtitle: Text(
            group.averagePendingAge == null
                ? 'Sin reportes pendientes'
                : statisticsDuration(group.averagePendingAge!),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pendiente más antiguo'),
          subtitle: Text(
            group.oldestPendingAge == null
                ? 'Sin reportes pendientes'
                : statisticsDuration(group.oldestPendingAge!),
          ),
        ),
        Text(
          'Pendientes: ${group.pending}. Incluye Reportado y En seguimiento; se cuenta desde la creación y se actualiza cada minuto.',
        ),
        if (group.pendingByAge.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Pendientes por antigüedad',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final range in PendingAgeRange.values)
            _MetricBar(
              label: range.label,
              value: group.pendingByAge[range] ?? 0,
              total: group.pending,
            ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tiempo promedio de resolución'),
          subtitle: Text(
            group.averageResolutionTime == null
                ? 'Sin reportes solucionados'
                : statisticsDuration(group.averageResolutionTime!),
          ),
        ),
        Text(
          'Muestra: ${group.resolved} reportes actualmente solucionados. Se mide desde creación hasta la última resolución. Los reabiertos quedan fuera de este promedio.',
        ),
        const SizedBox(height: 16),
        Text(
          'Reportes por categoría',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final category
            in [...group.categories]..sort((a, b) {
              final byTotal = b.total.compareTo(a.total);
              return byTotal == 0 ? a.name.compareTo(b.name) : byTotal;
            }))
          _MetricBar(
            label: '${category.name}${category.isActive ? '' : ' (inactiva)'}',
            value: category.total,
            total: group.total,
          ),
      ],
    ],
  );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: $value'),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 8,
          ),
        ),
      ],
    ),
  );
}
