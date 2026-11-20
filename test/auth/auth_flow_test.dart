import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';
import 'package:reporte_ciudadano_mvp/core/database/app_database.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/google_auth_repository.dart';
import 'package:reporte_ciudadano_mvp/features/auth/domain/auth_exception.dart';

import '../support/auth_fakes.dart';
import '../support/map_fakes.dart';
import '../support/composer_fakes.dart';

void main() {
  testWidgets(
    'protected action resumes after Google and a chosen name; logout returns to visitor',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = TestIdentityGateway();
      final repository = GoogleAuthRepository(db, gateway);
      await tester.runAsync(
        () => db.customSelect('SELECT * FROM categories').get(),
      );
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: db,
            authRepository: repository,
            location: TestLocation(),
            tiles: TestTiles.new,
            draftStore: MemoryDrafts(),
            photoSelection: QueuePhotos(),
            photoStorage: MemoryPhotos(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        expect(find.text('Iniciar sesión'), findsOneWidget);
        await tester.tap(find.text('Continuar con Google'));
        await tester.pumpAndSettle();
        expect(find.text('Elige tu nombre público'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          isEmpty,
        );
        await tester.tap(find.text('Completar más tarde y explorar'));
        await tester.pumpAndSettle();
        expect(find.text('Mapa de El Alto'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        expect(find.text('Elige tu nombre público'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), 'Vecina del barrio');
        await tester.tap(find.text('Guardar nombre'));
        await tester.pumpAndSettle();
        expect(find.text('Crear reporte'), findsOneWidget);
        expect(find.text('Título'), findsOneWidget);
        expect(gateway.signIns, 1);
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();
        expect(find.text('Mis reportes'), findsOneWidget);
        expect(find.text('Administrador local'), findsNothing);
        await tester.ensureVisible(find.text('Cerrar sesión'));
        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();
        expect(find.text('Estás explorando como visitante.'), findsOneWidget);
        expect(repository.currentUser, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = repository.close().then((_) => closed = true);
        for (var i = 0; i < 10 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(closed, isTrue);
        await closing;
        await gateway.events.close();
        await tester.runAsync(db.close);
      }
    },
  );

  testWidgets(
    'cancelled Google login stays on login and exploration remains available',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = TestIdentityGateway()..failure = AuthFailure.cancelled;
      final repository = GoogleAuthRepository(db, gateway);
      await tester.runAsync(
        () => db.customSelect('SELECT * FROM categories').get(),
      );
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: db,
            authRepository: repository,
            location: TestLocation(),
            tiles: TestTiles.new,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar con Google'));
        await tester.pumpAndSettle();
        expect(find.text('Se canceló el inicio de sesión.'), findsOneWidget);
        expect(repository.currentUser, isNull);
        await tester.tap(find.text('Seguir explorando sin sesión'));
        await tester.pumpAndSettle();
        expect(find.text('Mapa de El Alto'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = repository.close().then((_) => closed = true);
        for (var i = 0; i < 10 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(closed, isTrue);
        await closing;
        await gateway.events.close();
        await tester.runAsync(db.close);
      }
    },
  );
}
