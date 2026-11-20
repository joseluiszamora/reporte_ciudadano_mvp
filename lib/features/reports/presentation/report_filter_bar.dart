import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../categories/domain/category_repository.dart';
import '../domain/report_filter.dart';
import '../domain/report_policy.dart';
import 'report_filter_cubit.dart';
import 'report_labels.dart';

class ReportFilterBar extends StatefulWidget {
  const ReportFilterBar({
    super.key,
    required this.filters,
    required this.categories,
  });
  final ReportFilterCubit filters;
  final CategoryRepository categories;
  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  late final search = TextEditingController(text: widget.filters.state.search);
  bool opening = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> openFilters() async {
    FocusScope.of(context).unfocus();
    if (opening) return;
    opening = true;
    try {
      final categories = await widget.categories.watchCategories().first;
      if (!mounted) return;
      final filter = await showModalBottomSheet<ReportFilter>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            _FilterSheet(filter: widget.filters.state, categories: categories),
      );
      if (mounted && filter != null) widget.filters.apply(filter);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron cargar los filtros. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      opening = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ReportFilterCubit, ReportFilter>(
        bloc: widget.filters,
        listener: (_, filter) {
          if (search.text != filter.search) search.text = filter.search;
        },
        builder: (context, filter) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      controller: search,
                      onChanged: widget.filters.search,
                      decoration: const InputDecoration(
                        labelText: 'Buscar reportes',
                        hintText: 'Título o descripción',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: openFilters,
                    tooltip: 'Filtrar y ordenar',
                    icon: const Icon(Icons.tune),
                  ),
                  if (filter.isActive)
                    IconButton(
                      onPressed: widget.filters.reset,
                      tooltip: 'Limpiar filtros',
                      icon: const Icon(Icons.filter_alt_off_outlined),
                    ),
                ],
              ),
              if (filter.isActive && View.of(context).viewInsets.bottom == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Filtros compartidos con el mapa y la lista.'),
                ),
            ],
          ),
        ),
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter, required this.categories});
  final ReportFilter filter;
  final List<ReportCategory> categories;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? category = widget.filter.categoryId;
  late ReportStatus? status = widget.filter.status;
  late ReportOrder order = widget.filter.order;
  late DateTime? from = widget.filter.from;
  late DateTime? until = widget.filter.until;
  Future<void> dates() async {
    final last = until?.toLocal();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: from == null || until == null
          ? null
          : DateTimeRange(
              start: from!.toLocal(),
              end: DateTime(last!.year, last.month, last.day - 1),
            ),
    );
    if (mounted && range != null) {
      setState(() {
        from = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        ).toUtc();
        until = DateTime(
          range.end.year,
          range.end.month,
          range.end.day + 1,
        ).toUtc();
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrar y ordenar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            hint: const Text('Todas las categorías'),
            initialValue: category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todas las categorías'),
              ),
              for (final item in widget.categories)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    '${item.name}${item.isActive ? '' : ' (inactiva)'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => category = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReportStatus>(
            hint: const Text('Todos los estados'),
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todos los estados'),
              ),
              for (final item in ReportStatus.values)
                DropdownMenuItem(
                  value: item,
                  child: Text(ReportLabels.status(item)),
                ),
            ],
            onChanged: (value) => setState(() => status = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReportOrder>(
            initialValue: order,
            decoration: const InputDecoration(labelText: 'Orden'),
            items: const [
              DropdownMenuItem(
                value: ReportOrder.newest,
                child: Text('Más recientes'),
              ),
              DropdownMenuItem(
                value: ReportOrder.oldest,
                child: Text('Más antiguos'),
              ),
            ],
            onChanged: (value) => setState(() => order = value!),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: dates,
            icon: const Icon(Icons.date_range),
            label: Text(
              from == null
                  ? 'Elegir fechas de creación'
                  : '${ReportLabels.date(from!, time: false)} — ${ReportLabels.date(until!.subtract(const Duration(microseconds: 1)), time: false)}',
            ),
          ),
          if (from != null)
            TextButton(
              onPressed: () => setState(() {
                from = null;
                until = null;
              }),
              child: const Text('Quitar fechas'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              ReportFilter(
                search: widget.filter.search,
                categoryId: category,
                status: status,
                from: from,
                until: until,
                order: order,
              ),
            ),
            child: const Text('Aplicar filtros'),
          ),
        ],
      ),
    ),
  );
}
