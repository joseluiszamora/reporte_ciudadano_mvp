import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/errors/repository_exception.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/google_auth_repository.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/identity_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/auth/presentation/auth_cubit.dart';
import 'package:reporte_ciudadano_mvp/features/profile/data/sqlite_my_reports_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_repository.dart';

import '../support/auth_fakes.dart';
import '../support/local_fixture.dart';

class SwitchingPhotoStorage extends TestPhotoStorage {
  SwitchingPhotoStorage(this.switchAccount);
  final void Function() switchAccount;
  @override
  Future<bool> exists(String relativePath) async {
    switchAccount();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('my reports follows active account, including anonymous reports, without mixing authors', () async {
    final fixture = LocalFixture();
    await fixture.initialize();
    final own = await fixture.reports.create(fixture.draft());
    fixture.uid = 'other';
    await fixture.users.recordGoogleSignIn(uid: 'other');
    await fixture.users.completePublicName('Otra persona');
    final other = await fixture.reports.create(
      fixture.draft(
        title: 'Basura en otra avenida',
        images: [
          const StoredPhoto(
            relativePath: 'photos/b.jpg',
            mimeType: 'image/jpeg',
            bytes: 100,
          ),
        ],
      ),
    );
    final gateway = TestIdentityGateway(
      next: const VerifiedIdentity(uid: 'owner'),
    );
    final repository = GoogleAuthRepository(fixture.db, gateway);
    try {
      await repository.initialize();
      await repository.signInWithGoogle();
      final mine = SqliteMyReportsRepository(fixture.db, repository.session);
      expect((await mine.watchMine().first).map((item) => item.id), [own]);
      await repository.signOut();
      gateway.next = const VerifiedIdentity(uid: 'other');
      await repository.signInWithGoogle();
      expect((await mine.watchMine().first).map((item) => item.id), [other]);
    } finally {
      await repository.close();
      await gateway.events.close();
      await fixture.db.close();
    }
  });

  test(
    'account change during photo validation cancels a report transaction',
    () async {
      final fixture = LocalFixture();
      await fixture.initialize();
      try {
        final reports = SqliteReportRepository(
          fixture.db,
          fixture.session,
          SwitchingPhotoStorage(() => fixture.uid = null),
        );
        await expectLater(
          reports.create(fixture.draft()),
          throwsA(
            isA<RepositoryException>().having(
              (error) => error.code,
              'code',
              RepositoryError.unauthenticated,
            ),
          ),
        );
        expect(
          await fixture.db.customSelect('SELECT * FROM reports').get(),
          isEmpty,
        );
      } finally {
        await fixture.db.close();
      }
    },
  );

  test('double sign-in submission starts only one provider flow', () async {
    final fixture = LocalFixture();
    final pending = Completer<VerifiedIdentity>();
    final gateway = TestIdentityGateway()..pending = pending.future;
    final repository = GoogleAuthRepository(fixture.db, gateway);
    final cubit = AuthCubit(repository);
    try {
      await cubit.initialize();
      final first = cubit.signIn();
      final second = cubit.signIn();
      pending.complete(const VerifiedIdentity(uid: 'google-user'));
      await Future.wait([first, second]);
      expect(gateway.signIns, 1);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.user!.uid, 'google-user');
    } finally {
      await cubit.close();
      await repository.close();
      await gateway.events.close();
      await fixture.db.close();
    }
  });
}
