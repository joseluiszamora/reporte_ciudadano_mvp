import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:reporte_ciudadano_mvp/core/database/app_database.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';

import 'support/map_fakes.dart';

void main() {
  testWidgets('catalog loads from SQLite and reloads after leaving the route', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(
      () => db.customSelect('SELECT * FROM categories').get(),
    );
    await tester.pumpWidget(
      CitizenReportsApp(
        database: db,
        location: TestLocation(),
        tiles: TestTiles.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no hay reportes en este teléfono.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ver categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Categorías disponibles'), findsOneWidget);
    expect(find.text('Baches y daños en las calles'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Baches y daños en las calles'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  testWidgets(
    'visitor navigates foundation routes without fake data or login',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.runAsync(
        () => db.customSelect('SELECT * FROM categories').get(),
      );
      final location = TestLocation();
      await tester.pumpWidget(
        CitizenReportsApp(
          database: db,
          location: location,
          tiles: TestTiles.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mapa de El Alto'), findsOneWidget);
      expect(location.calls, 0);
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Estás explorando como visitante'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    },
  );
}
