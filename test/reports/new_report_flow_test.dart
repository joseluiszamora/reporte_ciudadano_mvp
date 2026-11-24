import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/google_auth_repository.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/identity_gateway.dart';

import '../support/auth_fakes.dart';
import '../support/composer_fakes.dart';
import '../support/local_fixture.dart';
import '../support/map_fakes.dart';
import 'report_browsing_test.dart' show MissingPhotos;

void main() {
  testWidgets(
    'switching to another complete account never displays the previous draft',
    (tester) async {
      final fixture = LocalFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        fixture.uid = 'other';
        await fixture.users.recordGoogleSignIn(uid: 'other');
        await fixture.users.completePublicName('Otra persona');
        fixture.uid = 'owner';
      });
      final gateway = TestIdentityGateway(
        current: const VerifiedIdentity(uid: 'owner'),
      );
      final auth = GoogleAuthRepository(fixture.db, gateway);
      final drafts = MemoryDrafts();
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: fixture.db,
            authRepository: auth,
            location: TestLocation(),
            tiles: TestTiles.new,
            photos: MissingPhotos(),
            photoStorage: MemoryPhotos(),
            photoSelection: QueuePhotos(),
            draftStore: drafts,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reportar'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Título'),
          'Borrador privado del primer usuario',
        );
        gateway.change(const VerifiedIdentity(uid: 'other'));
        for (
          var step = 0;
          step < 10 && auth.currentUser?.uid != 'other';
          step++
        ) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(auth.currentUser!.uid, 'other');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Título'))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          drafts.drafts['owner']!.title,
          'Borrador privado del primer usuario',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = auth.close().then((_) => closed = true);
        for (var i = 0; i < 10 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        await closing;
        await gateway.events.close();
        await tester.runAsync(fixture.db.close);
      }
    },
  );
  testWidgets(
    'visitor resumes draft, signs in during review and saves an anonymous report',
    (tester) async {
      final fixture = LocalFixture();
      await tester.runAsync(fixture.initialize);
      final gateway = TestIdentityGateway(
        next: const VerifiedIdentity(uid: 'owner'),
      );
      final auth = GoogleAuthRepository(fixture.db, gateway);
      final drafts = MemoryDrafts();
      final storage = MemoryPhotos();
      final picker = QueuePhotos()..next = ['camera-photo'];
      Future<void> show(String text) async {
        for (
          var step = 0;
          step < 25 && find.text(text).hitTestable().evaluate().isEmpty;
          step++
        ) {
          final viewport = tester.getRect(find.byType(ListView).first);
          await tester.dragFrom(
            Offset(viewport.left + 4, viewport.bottom - 30),
            const Offset(0, -180),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(text));
      }

      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: fixture.db,
            authRepository: auth,
            location: TestLocation(),
            tiles: TestTiles.new,
            photos: MissingPhotos(),
            photoStorage: storage,
            photoSelection: picker,
            draftStore: drafts,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reportar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Baches y daños en las calles').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Título'),
          'Bache en la avenida principal',
        );
        await show('Descripción');
        await tester.enterText(
          find.widgetWithText(TextField, 'Descripción'),
          'Un bache dificulta el paso de vehículos en la avenida.',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reportar'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Título'))
              .controller!
              .text,
          'Bache en la avenida principal',
        );
        await show('Continuar');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        await show('Galería');
        await tester.tap(find.text('Galería'));
        await tester.pumpAndSettle();
        await show('Continuar');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        await show('Elegir ubicación');
        await tester.tap(find.text('Elegir ubicación'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Coordenadas'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Latitud'),
          '-16.5',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Longitud'),
          '-68.15',
        );
        await tester.tap(find.text('Usar coordenadas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar ubicación'));
        await tester.pumpAndSettle();
        await show('Revisar reporte');
        await tester.tap(find.text('Revisar reporte'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
        await tester.pumpAndSettle();
        expect(find.text('Vista previa del reporte'), findsOneWidget);
        await show('Autor: Ciudadano anónimo');
        expect(find.text('Autor: Ciudadano anónimo'), findsOneWidget);
        expect(
          await tester.runAsync(
            () => fixture.db.customSelect('SELECT * FROM reports').get(),
          ),
          isEmpty,
        );
        expect(auth.currentUser, isNull);
        expect(find.text('Guardar reporte'), findsNothing);
        await show('Continuar con Google');
        await tester.tap(find.text('Continuar con Google'));
        await tester.pumpAndSettle();
        expect(auth.currentUser?.uid, 'owner');
        expect(gateway.signIns, 1);
        await show('Guardar reporte');
        await tester.tap(find.text('Guardar reporte'));
        await tester.pumpAndSettle();
        expect(find.text('Detalle del reporte'), findsOneWidget);
        expect(find.text('Autor: Ciudadano anónimo'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Bache en la avenida principal'), findsOneWidget);
        expect(drafts.drafts, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = auth.close().then((_) => closed = true);
        for (var i = 0; i < 10 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        await closing;
        await gateway.events.close();
        await tester.runAsync(fixture.db.close);
      }
    },
  );
}
