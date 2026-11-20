import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';
import 'package:reporte_ciudadano_mvp/core/media/local_photo_reader.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';

import '../support/local_fixture.dart';
import '../support/map_fakes.dart';

class MissingPhotos implements LocalPhotoReader {
  @override
  Future<File?> open(String relativePath) async => null;
}

void main() {
  testWidgets(
    'map search remains usable with the Android keyboard on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final fixture = LocalFixture();
      await tester.runAsync(fixture.initialize);
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: fixture.db,
            location: TestLocation(),
            tiles: TestTiles.new,
            photos: MissingPhotos(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.enterText(find.byType(TextField), 'basura');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.db.close);
      }
    },
  );
  testWidgets(
    'search is retained across list/map and marker opens anonymous full detail',
    (tester) async {
      final fixture = LocalFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        await fixture.reports.create(
          fixture.draft(title: 'Bache avenida Principal'),
        );
        await fixture.reports.create(
          fixture.draft(
            title: 'Basura avenida Central',
            category: 'basura',
            images: [
              const StoredPhoto(
                relativePath: 'photos/b.jpg',
                mimeType: 'image/jpeg',
                bytes: 100,
              ),
            ],
          ),
        );
      });
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: fixture.db,
            location: TestLocation(),
            tiles: TestTiles.new,
            photos: MissingPhotos(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.list_alt));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'basura');
        await tester.pumpAndSettle();
        expect(find.text('Basura avenida Central'), findsOneWidget);
        expect(find.text('Bache avenida Principal'), findsNothing);
        await tester.tap(find.byIcon(Icons.map_outlined));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'basura',
        );
        await tester.tap(
          find.byTooltip(
            'Basura avenida Central · Basura y acumulación de residuos · Reportado',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Detalle del reporte'), findsOneWidget);
        expect(find.text('Autor: Ciudadano anónimo'), findsOneWidget);
        expect(find.textContaining('private@example.test'), findsNothing);
        expect(find.text('Fotografía no disponible'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Historial y propuestas'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Reporte creado'), findsWidgets);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'basura',
        );
        await tester.tap(find.byIcon(Icons.list_alt));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Limpiar filtros'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.db.close);
      }
    },
  );

  testWidgets(
    'status filter yields a recoverable empty result and reset restores report',
    (tester) async {
      final fixture = LocalFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        await fixture.reports.create(fixture.draft());
      });
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: fixture.db,
            location: TestLocation(),
            tiles: TestTiles.new,
            photos: MissingPhotos(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.list_alt));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Filtrar y ordenar'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Todos los estados'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Solucionado').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aplicar filtros'));
        await tester.pumpAndSettle();
        expect(
          find.text('No hay reportes que coincidan con los filtros.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Limpiar filtros'));
        await tester.pumpAndSettle();
        expect(find.text('Bache en avenida'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.db.close);
      }
    },
  );
}
