import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/reports/domain/report_policy.dart';
import '../../features/reports/presentation/report_labels.dart';
import '../errors/action_error_message.dart';
import 'audit_repository.dart';
import 'sqlite_audit_repository.dart';

class AuditPage extends StatelessWidget {
  const AuditPage({super.key, required this.auth, required this.repository});
  final AuthCubit auth;
  final AuditRepository repository;
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    bloc: auth,
    builder: (context, state) {
      if (!ReportPolicy.canManage(state.user)) {
        return Scaffold(
          appBar: AppBar(title: const Text('Informe de acciones')),
          body: const Center(
            child: Text('Esta pantalla requiere permisos de administrador.'),
          ),
        );
      }
      return _Audit(
        key: ValueKey('${state.user!.uid}:${state.user!.role}'),
        repository: repository,
      );
    },
  );
}

class _Audit extends StatefulWidget {
  const _Audit({super.key, required this.repository});
  final AuditRepository repository;
  @override
  State<_Audit> createState() => _AuditState();
}

class _AuditState extends State<_Audit> {
  final actor = TextEditingController();
  final action = TextEditingController();
  final entity = TextEditingController();
  String? entityType;
  bool? demo;
  DateTimeRange? range;
  bool csv = false;
  late Future<List<Map<String, Object?>>> result = query(const AuditFilter());
  Future<List<Map<String, Object?>>> query(AuditFilter filter) {
    final future = widget.repository.query(filter);
    future.ignore(); // Attach error observation before the next UI frame.
    return future;
  }

  @override
  void dispose() {
    actor.dispose();
    action.dispose();
    entity.dispose();
    super.dispose();
  }

  void search() => setState(() {
    csv = false;
    result = query(
      AuditFilter(
        actorUid: actor.text,
        action: action.text,
        entityType: entityType,
        entityId: entity.text,
        isDemo: demo,
        from: range?.start,
        to: range == null
            ? null
            : DateTime(range!.end.year, range!.end.month, range!.end.day + 1),
      ),
    );
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Informe de acciones')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Información privada de este teléfono. Incluye acciones sobre reportes eliminados. Se muestran hasta los 500 eventos más recientes de cada consulta; ajusta filtros para revisar otros períodos.',
        ),
        TextField(
          controller: actor,
          decoration: const InputDecoration(
            labelText: 'UID del actor (exacto)',
          ),
        ),
        TextField(
          controller: action,
          decoration: const InputDecoration(
            labelText: 'Acción (ej. REPORT_DELETED)',
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: entityType,
          decoration: const InputDecoration(labelText: 'Tipo de entidad'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            for (final type in ['report', 'proposal', 'user'])
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) => setState(() => entityType = value),
        ),
        TextField(
          controller: entity,
          decoration: const InputDecoration(
            labelText: 'ID de entidad (exacto)',
          ),
        ),
        DropdownButtonFormField<bool>(
          initialValue: demo,
          decoration: const InputDecoration(labelText: 'Origen de datos'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Todos')),
            DropdownMenuItem(value: false, child: Text('Sin demostración')),
            DropdownMenuItem(value: true, child: Text('Solo demostración')),
          ],
          onChanged: (value) => setState(() => demo = value),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                final chosen = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: range,
                );
                if (chosen != null && mounted) setState(() => range = chosen);
              },
              child: Text(
                range == null
                    ? 'Elegir fechas'
                    : '${ReportLabels.date(range!.start)} — ${ReportLabels.date(range!.end)}',
              ),
            ),
            if (range != null)
              TextButton(
                onPressed: () => setState(() => range = null),
                child: const Text('Quitar fechas'),
              ),
          ],
        ),
        FilledButton(
          onPressed: search,
          child: const Text('Consultar acciones'),
        ),
        FutureBuilder<List<Map<String, Object?>>>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(actionErrorMessage(snapshot.error!));
            }
            final rows = snapshot.data ?? [];
            final totals = <String, int>{};
            final actors = <String, int>{};
            final entities = <String, int>{};
            for (final row in rows) {
              totals.update(
                '${row['action']}',
                (value) => value + 1,
                ifAbsent: () => 1,
              );
              actors.update(
                '${row['actor_uid'] ?? 'Sistema'}',
                (value) => value + 1,
                ifAbsent: () => 1,
              );
              entities.update(
                '${row['entity_type']}',
                (value) => value + 1,
                ifAbsent: () => 1,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rows.length} eventos encontrados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Resumen de los eventos mostrados'),
                for (final total in totals.entries)
                  Text('${total.key}: ${total.value}'),
                ExpansionTile(
                  title: const Text('Agrupar por actor'),
                  children: [
                    for (final total in actors.entries)
                      ListTile(
                        title: Text(total.key),
                        trailing: Text('${total.value}'),
                      ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Agrupar por tipo de entidad'),
                  children: [
                    for (final total in entities.entries)
                      ListTile(
                        title: Text(total.key),
                        trailing: Text('${total.value}'),
                      ),
                  ],
                ),
                if (rows.isNotEmpty) ...[
                  OutlinedButton(
                    onPressed: () => setState(() => csv = !csv),
                    child: const Text('Exportar resultados como CSV'),
                  ),
                  if (csv) ...[
                    const Text(
                      'CSV privado de esta consulta, con fechas UTC. Copia el contenido para guardarlo como archivo .csv.',
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: auditCsv(rows)),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('CSV copiado.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar CSV'),
                    ),
                    SizedBox(
                      height: 180,
                      child: SingleChildScrollView(
                        child: SelectableText(auditCsv(rows)),
                      ),
                    ),
                  ],
                ],
                for (final row in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row['action']} · ${row['actor_role']}'),
                          Text('Actor: ${row['actor_uid'] ?? 'Sistema'}'),
                          Text(
                            '${row['entity_type']}: ${row['entity_id'] ?? ''}',
                          ),
                          Text(
                            ReportLabels.date(
                              DateTime.parse('${row['created_at']}'),
                            ),
                          ),
                          Text('Campos: ${row['changed_fields_json']}'),
                          if (row['reason'] != null)
                            Text('Motivo: ${row['reason']}'),
                          if (row['is_demo'] == 1) const Text('Demostración'),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
