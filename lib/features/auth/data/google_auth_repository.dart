import 'dart:async';

import '../../../core/audit/audit_dao.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_session.dart';
import '../domain/app_user.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import 'identity_gateway.dart';
import 'local_user_store.dart';

class GoogleAuthRepository implements AuthRepository {
  GoogleAuthRepository(this.db, this.gateway) {
    session = LocalSession(db, () => _uid);
    users = LocalUserStore(db, session);
  }
  final AppDatabase db;
  final IdentityGateway gateway;
  late final LocalSession session;
  late final LocalUserStore users;
  final _events = StreamController<AppUser?>.broadcast();
  StreamSubscription<VerifiedIdentity?>? _subscription;
  Future<void> _tail = Future.value();
  String? _uid;
  AppUser? _user;
  bool _blocked = false;
  bool _closed = false;
  int _epoch = 0;
  @override
  AppUser? get currentUser => _user;
  @override
  String? get configurationIssue => gateway.configurationIssue;

  @override
  Stream<AppUser?> watchUser() => Stream.multi((controller) {
    final subscription = _events.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_user);
    controller.onCancel = subscription.cancel;
  });

  void _publish(AppUser? user) {
    _user = user;
    if (!_closed) _events.add(user);
  }

  void _clear() {
    _uid = null;
    _publish(null);
  }

  Future<void> _accept(VerifiedIdentity? identity) {
    final epoch = _epoch;
    final work = _tail.then((_) async {
      if (_closed || epoch != _epoch || (_blocked && identity != null)) return;
      if (identity == null) {
        _clear();
        return;
      }
      final previous = _user?.uid;
      _uid = identity.uid;
      try {
        final role = identity.isAdmin ? UserRole.admin : UserRole.citizen;
        if (previous != identity.uid) {
          await users.recordGoogleSignIn(
            uid: identity.uid,
            email: identity.email,
            photoUrl: identity.photoUrl,
            verifiedRole: role,
          );
        } else {
          await users.refreshVerifiedRole(role);
        }
        final local = await session.requireUser();
        if (epoch == _epoch && !_blocked) _publish(local);
      } catch (_) {
        _clear();
        throw const AuthException(AuthFailure.storage);
      }
    });
    _tail = work.catchError((Object _) {});
    return work;
  }

  @override
  Future<void> initialize() async {
    if (_subscription != null) return;
    await gateway.initialize();
    final first = Completer<void>();
    _subscription = gateway.watchIdentity().listen(
      (identity) {
        unawaited(
          _accept(identity).then(
            (_) {
              if (!first.isCompleted) first.complete();
            },
            onError: (Object error, StackTrace stack) {
              if (!first.isCompleted) first.completeError(error, stack);
              if (!_closed) _events.addError(error, stack);
            },
          ),
        );
      },
      onError: (Object error, StackTrace stack) {
        _clear();
        if (!first.isCompleted) first.completeError(error, stack);
        if (!_closed) _events.addError(const AuthException(AuthFailure.denied));
      },
    );
    await first.future;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (configurationIssue != null) {
      throw const AuthException(AuthFailure.notConfigured);
    }
    _blocked = false;
    _epoch++;
    final epoch = _epoch;
    final identity = await gateway.signIn();
    if (_closed || epoch != _epoch) {
      // A provider can finish after logout. Clear that late SDK session too,
      // so it cannot be restored on the next launch.
      if (_blocked) await gateway.signOut();
      throw const AuthException(AuthFailure.cancelled);
    }
    await _accept(identity);
    return _user!;
  }

  @override
  Future<void> completeProfile(String publicName) async {
    await users.completePublicName(publicName);
    _publish(await session.requireUser());
  }

  @override
  Future<void> signOut() async {
    final actor = _user;
    _blocked = true;
    _epoch++;
    _clear();
    // Clear SDK persistence even if writing the logout audit fails.
    Object? failure;
    try {
      await gateway.signOut();
    } catch (_) {
      failure = const AuthException(AuthFailure.unknown);
    }
    if (actor != null) {
      try {
        await db.transaction(() async {
          await AuditDao(db).append(
            actor: actor,
            action: 'LOGOUT',
            entityType: 'user',
            entityId: actor.uid,
            at: DateTime.now(),
          );
          db.changed({'audit_events'});
        });
      } catch (_) {
        failure = const AuthException(AuthFailure.storage);
      }
    }
    if (failure != null) throw failure;
  }

  @override
  Future<void> close() async {
    _closed = true;
    _epoch++;
    _uid = null;
    await _subscription?.cancel();
    await _tail;
    await _events.close();
  }
}
