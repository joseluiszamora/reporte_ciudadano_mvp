import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/location/geo_point.dart';
import 'package:reporte_ciudadano_mvp/core/location/location_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/map/domain/map_report_repository.dart';
import 'package:reporte_ciudadano_mvp/features/map/presentation/city_map_page.dart';
import 'package:reporte_ciudadano_mvp/features/map/presentation/location_picker_page.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';

import '../support/map_fakes.dart';

void main() {
  testWidgets(
    'picker keeps controls accessible on a small screen with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: LocationPickerPage(
            location: TestLocation()..failure = LocationFailure.deniedForever,
            initial: GeoPoint(0, 0),
            tiles: TestTiles.new,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi ubicación'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirmar ubicación').hitTestable(), findsOneWidget);
    },
  );
  testWidgets(
    'picker requires selection, supports map taps and returns coordinates',
    (tester) async {
      final gateway = TestLocation();
      GeoPoint? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Abrir selector'),
                onPressed: () async {
                  result = await Navigator.push<GeoPoint>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPickerPage(
                        location: gateway,
                        tiles: TestTiles.new,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir selector'));
      await tester.pumpAndSettle();
      expect(gateway.calls, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar ubicación'),
            )
            .onPressed,
        isNull,
      );
      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.initialCenter.latitude, -16.5);
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      // A single map tap is dispatched after the double-tap interval.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('Punto elegido:'), findsOneWidget);
      await tester.tap(find.text('Confirmar ubicación'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.distanceTo(GeoPoint.elAlto), lessThan(100));
    },
  );

  testWidgets(
    'GPS denial leaves manual coordinate entry and confirmation available',
    (tester) async {
      final gateway = TestLocation()..failure = LocationFailure.denied;
      await tester.pumpWidget(
        MaterialApp(
          home: LocationPickerPage(location: gateway, tiles: TestTiles.new),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi ubicación'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se concedió acceso'), findsOneWidget);
      await tester.tap(find.text('Coordenadas'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Latitud'),
        '-16,51',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Longitud'),
        '-68.16',
      );
      await tester.tap(find.text('Usar coordenadas'));
      await tester.pumpAndSettle();
      expect(
        find.text('Punto elegido: -16.510000, -68.160000'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar ubicación'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'permanent denial offers settings and outlying coordinates remain selectable',
    (tester) async {
      final gateway = TestLocation()..failure = LocationFailure.deniedForever;
      await tester.pumpWidget(
        MaterialApp(
          home: LocationPickerPage(
            location: gateway,
            initial: GeoPoint(0, 0),
            tiles: TestTiles.new,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('más de 30 km'), findsOneWidget);
      await tester.tap(find.text('Mi ubicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir ajustes de permisos'));
      await tester.pumpAndSettle();
      expect(gateway.openedAppSettings, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar ubicación'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('marker opens local summary and attribution is always visible', (
    tester,
  ) async {
    final report = MapReport(
      id: 'r',
      title: 'Bache en avenida',
      category: 'Baches',
      point: GeoPoint.elAlto,
      status: ReportStatus.reported,
      isDemo: true,
    );
    final location = TestLocation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CityMapPage(
            reports: TestMapReports([report]),
            location: location,
            tiles: TestTiles.new,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(location.calls, 0);
    await tester.tap(
      find.byTooltip('Bache en avenida · Baches · Reportado · Demostración'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reportado'), findsOneWidget);
    expect(find.text('Datos de demostración'), findsOneWidget);
  });

  testWidgets('failed tiles show retry and retry recreates the provider', (
    tester,
  ) async {
    var fail = true;
    var providers = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPickerPage(
          location: TestLocation(),
          tiles: () {
            providers++;
            return TestTiles(fail: fail);
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Coordenadas'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(providers, 2);
    expect(find.text('Reintentar'), findsNothing);
  });
}
