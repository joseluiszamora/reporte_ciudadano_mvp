import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../features/auth/domain/app_user.dart';
import '../database/app_database.dart';

class AuditDao {
  AuditDao(this.db);
  final AppDatabase db;

  /// Call inside the same transaction as the mutation. No update/delete API.
  Future<void> append({
    required AppUser actor,
    required String action,
    required String entityType,
    required String entityId,
    required DateTime at,
    List<String> changedFields = const [],
    String? reason,
    bool isDemo = false,
  }) => db.customStatement(
    '''
        INSERT INTO audit_events(id,actor_uid,actor_role,action,entity_type,entity_id,
          changed_fields_json,reason,created_at,is_demo) VALUES(?,?,?,?,?,?,?,?,?,?)
      ''',
    [
      const Uuid().v4(),
      actor.uid,
      actor.role == UserRole.admin ? 'ADMIN' : 'CITIZEN',
      action,
      entityType,
      entityId,
      jsonEncode(changedFields),
      reason,
      at.toUtc().toIso8601String(),
      isDemo ? 1 : 0,
    ],
  );
}
