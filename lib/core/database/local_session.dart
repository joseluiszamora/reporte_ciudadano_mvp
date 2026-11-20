import 'package:drift/drift.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/reports/domain/report_policy.dart';
import '../errors/repository_exception.dart';
import 'app_database.dart';

/// UID must come from the auth adapter, never a form or a role chosen in UI.
typedef SessionUid = String? Function();

class LocalSession {
  LocalSession(this.db, this.currentUid);
  final AppDatabase db;
  final SessionUid currentUid;

  void ensureCurrent(AppUser actor) {
    if (currentUid() != actor.uid) {
      throw const RepositoryException(
        RepositoryError.unauthenticated,
        'La sesión cambió. Vuelve a iniciar sesión para continuar.',
      );
    }
  }

  Future<AppUser> requireUser() async {
    final uid = currentUid();
    if (uid == null) {
      throw const RepositoryException(
        RepositoryError.unauthenticated,
        'Inicia sesión para continuar.',
      );
    }
    final row = await db
        .customSelect(
          'SELECT id,public_name,role FROM users WHERE id = ?',
          variables: [Variable.withString(uid)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const RepositoryException(
        RepositoryError.unauthenticated,
        'La sesión local no está disponible.',
      );
    }
    return AppUser(
      uid: row.read<String>('id'),
      publicName: row.readNullable<String>('public_name') ?? '',
      role: row.read<String>('role') == 'ADMIN'
          ? UserRole.admin
          : UserRole.citizen,
    );
  }

  Future<AppUser> requireCompleteProfile() async {
    final actor = await requireUser();
    if (!ReportPolicy.canCreate(actor)) {
      throw const RepositoryException(
        RepositoryError.forbidden,
        'Completa tu nombre público para continuar.',
      );
    }
    return actor;
  }
}
