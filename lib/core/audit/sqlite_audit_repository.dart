import 'package:drift/drift.dart';

import '../../features/reports/domain/report_policy.dart';
import '../database/app_database.dart';
import '../database/local_session.dart';
import '../errors/repository_exception.dart';
import 'audit_repository.dart';

class SqliteAuditRepository implements AuditRepository {
  SqliteAuditRepository(this.db, this.session);
  final AppDatabase db;
  final LocalSession session;
  static const maxRows = 500;
  @override
  Future<List<Map<String, Object?>>> query(
    AuditFilter filter,
  ) => db.transaction(() async {
    final actor = await session.requireCompleteProfile();
    if (!ReportPolicy.canManage(actor)) {
      throw const RepositoryException(
        RepositoryError.forbidden,
        'El informe de acciones es privado para administración.',
      );
    }
    if (filter.from != null &&
        filter.to != null &&
        !filter.from!.isBefore(filter.to!)) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'Revisa el intervalo de fechas.',
      );
    }
    final where = <String>[];
    final args = <Variable>[];
    for (final field in {
      'actor_uid': filter.actorUid,
      'action': filter.action,
      'entity_type': filter.entityType,
      'entity_id': filter.entityId,
    }.entries) {
      if (field.value?.trim().isNotEmpty ?? false) {
        where.add('${field.key}=?');
        args.add(Variable.withString(field.value!.trim()));
      }
    }
    if (filter.isDemo != null) {
      where.add('is_demo=?');
      args.add(Variable.withInt(filter.isDemo! ? 1 : 0));
    }
    if (filter.from != null) {
      where.add('created_at>=?');
      args.add(Variable.withString(filter.from!.toUtc().toIso8601String()));
    }
    if (filter.to != null) {
      where.add('created_at<?');
      args.add(Variable.withString(filter.to!.toUtc().toIso8601String()));
    }
    final rows = await db
        .customSelect(
          'SELECT * FROM audit_events ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY created_at DESC,id DESC LIMIT $maxRows',
          variables: args,
        )
        .get();
    session.ensureCurrent(actor);
    return List.unmodifiable(
      rows.map((row) => Map<String, Object?>.unmodifiable(row.data)),
    );
  });
}

/// Every cell is quoted; prefix spreadsheet formulas even after whitespace.
String auditCsv(List<Map<String, Object?>> rows) {
  const fields = [
    'id',
    'actor_uid',
    'actor_role',
    'action',
    'entity_type',
    'entity_id',
    'changed_fields_json',
    'reason',
    'created_at',
    'is_demo',
  ];
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^\s*[=+\-@]').hasMatch(text) ||
        text.startsWith('\t') ||
        text.startsWith('\r')) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return [
    fields.map(cell).join(','),
    for (final row in rows) fields.map((key) => cell(row[key])).join(','),
  ].join('\r\n');
}
