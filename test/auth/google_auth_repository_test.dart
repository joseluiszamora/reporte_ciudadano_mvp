import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/database/app_database.dart';
import 'package:reporte_ciudadano_mvp/core/errors/repository_exception.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/firebase_auth_config.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/firebase_google_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/google_auth_repository.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/identity_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/auth/domain/app_user.dart';
import 'package:reporte_ciudadano_mvp/features/auth/domain/auth_exception.dart';
import 'package:reporte_ciudadano_mvp/features/auth/presentation/auth_route_guard.dart';
import 'package:reporte_ciudadano_mvp/features/auth/presentation/auth_cubit.dart';

import '../support/auth_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late TestIdentityGateway gateway;
  late GoogleAuthRepository repository;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = TestIdentityGateway();
    repository = GoogleAuthRepository(db, gateway);
    await repository.initialize();
  });
  tearDown(() async {
    await repository.close();
    await gateway.events.close();
    await db.close();
  });

  test('Google UID is preserved, name is chosen separately and duplicate SDK event logs once', () async {
    final user = await repository.signInWithGoogle();
    expect(user.uid, 'google-user');
    expect(user.publicName, isEmpty);
    expect(user.role, UserRole.citizen);
    await repository.completeProfile('  Vecina  ');
    expect(repository.currentUser!.publicName, 'Vecina');
    expect(
      await db
          .customSelect("SELECT * FROM audit_events WHERE action='LOGIN'")
          .get(),
      hasLength(1),
    );
    expect(
      await db
          .customSelect(
            "SELECT * FROM audit_events WHERE action='PROFILE_COMPLETED'",
          )
          .get(),
      hasLength(1),
    );
  });
  test('cancel and network failures never create a local user', () async {
    gateway.failure = AuthFailure.cancelled;
    await expectLater(
      repository.signInWithGoogle(),
      throwsA(isA<AuthException>()),
    );
    gateway.failure = AuthFailure.network;
    await expectLater(
      repository.signInWithGoogle(),
      throwsA(isA<AuthException>()),
    );
    expect(repository.currentUser, isNull);
    expect(await db.customSelect('SELECT * FROM users').get(), isEmpty);
  });
  test('name validation does not complete a profile or grant admin', () async {
    await repository.signInWithGoogle();
    await expectLater(
      repository.completeProfile(' '),
      throwsA(isA<RepositoryException>()),
    );
    await repository.completeProfile('Administrador');
    expect(repository.currentUser!.role, UserRole.citizen);
  });
  test(
    'verified claim grants admin and a refreshed false claim removes it',
    () async {
      gateway.next = const VerifiedIdentity(uid: 'google-user', isAdmin: true);
      await repository.signInWithGoogle();
      await repository.completeProfile('Moderación');
      expect(repository.currentUser!.role, UserRole.admin);
      final changed = repository.watchUser().firstWhere(
        (user) => user?.role == UserRole.citizen,
      );
      gateway.change(const VerifiedIdentity(uid: 'google-user'));
      expect(
        (await changed.timeout(const Duration(seconds: 5)))!.role,
        UserRole.citizen,
      );
      expect((await repository.session.requireUser()).role, UserRole.citizen);
    },
  );
  test(
    'logout clears session, records event, and login preserves the chosen name',
    () async {
      await repository.signInWithGoogle();
      await repository.completeProfile('Vecina');
      await repository.signOut();
      expect(repository.currentUser, isNull);
      await expectLater(
        repository.session.requireUser(),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        await db
            .customSelect("SELECT * FROM audit_events WHERE action='LOGOUT'")
            .get(),
        hasLength(1),
      );
      expect((await repository.signInWithGoogle()).publicName, 'Vecina');
    },
  );
  test('failed logout audit still clears SDK and local session', () async {
    await repository.signInWithGoogle();
    await db.customStatement(
      "CREATE TRIGGER reject_logout BEFORE INSERT ON audit_events WHEN NEW.action='LOGOUT' BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(repository.signOut(), throwsA(isA<AuthException>()));
    expect(repository.currentUser, isNull);
    expect(gateway.signOuts, 1);
    expect(gateway.current, isNull);
  });
  test(
    'persisted identity restores the local profile in a new repository',
    () async {
      await repository.signInWithGoogle();
      await repository.completeProfile('Vecina');
      final restoredGateway = TestIdentityGateway(
        current: const VerifiedIdentity(uid: 'google-user'),
      );
      final restored = GoogleAuthRepository(db, restoredGateway);
      try {
        await restored.initialize();
        expect(restored.currentUser!.publicName, 'Vecina');
      } finally {
        await restored.close();
        await restoredGateway.events.close();
      }
    },
  );
  test('logout invalidates an in-flight Google login result', () async {
    final result = Completer<VerifiedIdentity>();
    gateway.pending = result.future;
    final login = repository.signInWithGoogle();
    final assertion = expectLater(login, throwsA(isA<AuthException>()));
    await repository.signOut();
    result.complete(const VerifiedIdentity(uid: 'late-user'));
    await assertion;
    expect(repository.currentUser, isNull);
    expect(gateway.current, isNull);
  });
  test(
    'missing Firebase configuration is safe for browsing and refuses sign-in',
    () async {
      final native = FirebaseGoogleGateway(config: const FirebaseAuthConfig());
      await native.initialize();
      expect(await native.watchIdentity().first, isNull);
      await expectLater(native.signIn(), throwsA(isA<AuthException>()));
    },
  );
  test('guards preserve protected target and reject arbitrary return URLs', () {
    final guest = const AuthState(initializing: false);
    final target = Uri.parse(authRedirect(guest, Uri.parse('/nuevo'))!);
    expect(target.path, '/acceso');
    expect(target.queryParameters['volver'], '/nuevo');
    const partial = AuthState(
      initializing: false,
      user: AppUser(uid: 'u', publicName: ''),
    );
    expect(Uri.parse(authRedirect(partial, target)!).path, '/nombre');
    const signed = AuthState(
      initializing: false,
      user: AppUser(uid: 'u', publicName: 'Vecina'),
    );
    expect(authRedirect(signed, Uri.parse('/nombre?volver=/nuevo')), '/nuevo');
    expect(
      authRedirect(signed, Uri.parse('/acceso?volver=https://example.test')),
      '/perfil',
    );
    expect(authRedirect(guest, Uri.parse('/mapa')), isNull);
  });
}
