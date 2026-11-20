import 'package:drift/drift.dart';

import '../../../core/audit/audit_dao.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_session.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/validation/input_limits.dart';
import '../domain/app_user.dart';

/// Persistence for a verified Google identity. Does not authenticate by itself.
class LocalUserStore {
  LocalUserStore(this.db, this.session, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final LocalSession session;
  final DateTime Function() clock;

  /// Only the future Google adapter calls this after verifying the identity.
  /// New identities always start as citizens; signing in never changes roles/names.
  Future<void> recordGoogleSignIn({
    required String uid,
    String? email,
    String? photoUrl,
  }) => db.transaction(() async {
    if (uid.trim().isEmpty || session.currentUid() != uid) {
      throw const RepositoryException(
        RepositoryError.unauthenticated,
        'Identidad de sesión no válida.',
      );
    }
    final now = clock().toUtc();
    await db.customStatement(
      '''
      INSERT INTO users(id,email,photo_url,created_at,last_sign_in_at) VALUES(?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET email=excluded.email,photo_url=excluded.photo_url,last_sign_in_at=excluded.last_sign_in_at
    ''',
      [uid, email, photoUrl, now.toIso8601String(), now.toIso8601String()],
    );
    final actor = await session.requireUser();
    await AuditDao(db).append(
      actor: actor,
      action: 'LOGIN',
      entityType: 'user',
      entityId: uid,
      at: now,
    );
    db.changed({'users', 'audit_events'});
  });

  Future<void> completePublicName(String name) => db.transaction(() async {
    if (InputLimits.text(
          name,
          min: InputLimits.nameMin,
          max: InputLimits.nameMax,
        ) !=
        null) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'El nombre debe tener entre 2 y 50 caracteres.',
      );
    }
    final before = await session.requireUser();
    final row = await db
        .customSelect(
          'SELECT public_name FROM users WHERE id=?',
          variables: [Variable.withString(before.uid)],
        )
        .getSingle();
    await db.customStatement('UPDATE users SET public_name=? WHERE id=?', [
      name.trim(),
      before.uid,
    ]);
    await AuditDao(db).append(
      actor: AppUser(
        uid: before.uid,
        publicName: name.trim(),
        role: before.role,
      ),
      action: row.readNullable<String>('public_name') == null
          ? 'PROFILE_COMPLETED'
          : 'PROFILE_UPDATED',
      entityType: 'user',
      entityId: before.uid,
      at: clock(),
      changedFields: ['public_name'],
    );
    db.changed({'users', 'audit_events'});
  });
}
