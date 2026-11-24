import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/categories/data/sqlite_category_repository.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/data/sqlite_statistics_repository.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/domain/statistics_repository.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/presentation/statistics_filter_cubit.dart';
import 'package:reporte_ciudadano_mvp/features/statistics/presentation/statistics_page.dart';

import '../support/local_fixture.dart';
import '../support/map_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  // Yield to native SQLite I/O without advancing fake time by minutes while
  // an animated loader waits for a real database thread.
  for (var step = 0; step < 60; step++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('La interfaz no terminó de actualizarse después de ceder a SQLite.');
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  // Indicators are in one scroll view, below filters on smaller phones.
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await settle(tester);
  for (
    var step = 0;
    step < 30 && target.hitTestable().evaluate().isEmpty;
    step++
  ) {
    position.jumpTo(
      (position.pixels + 180).clamp(0.0, position.maxScrollExtent).toDouble(),
    );
    await settle(tester);
  }
  await tester.ensureVisible(target);
  await settle(tester);
}

Future<void> reportListReady(WidgetTester tester) async {
  for (
    var step = 0;
    step < 60 && find.byType(ListView).evaluate().isEmpty;
    step++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await reveal(tester, find.text('Bache en avenida'));
}

Widget page(
  LocalFixture f,
  StatisticsRepository repository,
  StatisticsFilterCubit filters, {
  TextScaler? textScaler,
}) => MaterialApp(
  locale: const Locale('es', 'BO'),
  supportedLocales: const [Locale('es', 'BO')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: StatisticsPage(
      repository: repository,
      categories: SqliteCategoryRepository(f.db),
      filters: filters,
      onCreate: () {},
    ),
  ),
);

void metric(String prefix, String title, String value) {
  expect(
    find.descendant(
      of: find.byKey(ValueKey('$prefix:$title')),
      matching: find.text(value),
    ),
    findsOneWidget,
  );
}

class ControlledStatistics implements StatisticsRepository {
  final sources = <StreamController<LocalStatistics>>[];
  @override
  Stream<LocalStatistics> watch(StatisticsFilter filter) {
    final source = StreamController<LocalStatistics>.broadcast();
    sources.add(source);
    return source.stream;
  }

  Future<void> close() async {
    for (final source in sources) {
      await source.close();
    }
  }
}

LocalStatistics sample(int total) => LocalStatistics(
  local: StatisticsGroup(
    total: total,
    reported: total,
    inFollowUp: 0,
    resolved: 0,
    categories: [],
    averagePendingAge: total == 0 ? null : const Duration(hours: 2),
    oldestPendingAge: total == 0 ? null : const Duration(hours: 2),
    averageResolutionTime: null,
  ),
  demo: null,
  asOf: DateTime.utc(2026, 11, 20),
);

void main() {
  testWidgets(
    'visitor sees empty statistics without credentials and can begin a report',
    (tester) async {
      final f = LocalFixture();
      await tester.runAsync(
        () => f.db.customSelect('SELECT * FROM categories').get(),
      );
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: f.db,
            tiles: TestTiles.new,
            location: TestLocation(),
          ),
        );
        await settle(tester);
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Estadísticas'),
        );
        await settle(tester);
        expect(
          find.text('Estadísticas locales; no representan a toda la ciudad'),
          findsOneWidget,
        );
        await reveal(tester, find.byKey(const ValueKey('local:Total')));
        metric('local', 'Total', '0');
        metric('local', 'Solucionados', '0');
        expect(find.byKey(const ValueKey('demo:Total')), findsNothing);
        await reveal(tester, find.text('Crear reporte'));
        await tester.tap(find.text('Crear reporte'));
        await settle(tester);
        expect(find.text('Tipo de problema'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await tester.runAsync(f.db.close);
      }
    },
  );

  testWidgets(
    'demo stays separate, category filters survive tab navigation and do not alter report search',
    (tester) async {
      final f = LocalFixture();
      await tester.runAsync(() async {
        await f.initialize();
        await f.reports.create(f.draft());
        final demo = await f.reports.create(
          f.draft(
            category: 'basura',
            title: 'Basura de demostración',
            images: [
              const StoredPhoto(
                relativePath: 'photos/b.jpg',
                mimeType: 'image/jpeg',
                bytes: 100,
              ),
            ],
          ),
        );
        await f.db.customStatement('UPDATE reports SET is_demo=1 WHERE id=?', [
          demo,
        ]);
      });
      try {
        await tester.pumpWidget(
          CitizenReportsApp(
            database: f.db,
            tiles: TestTiles.new,
            location: TestLocation(),
          ),
        );
        await settle(tester);
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Reportes'),
        );
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'avenida');
        await settle(tester);
        await reportListReady(tester);
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Estadísticas'),
        );
        await settle(tester);
        await reveal(tester, find.byKey(const ValueKey('local:Total')));
        metric('local', 'Total', '1');
        await reveal(tester, find.text('Incluir demostración'));
        await tester.tap(find.byType(Switch));
        await settle(tester);
        metric('local', 'Total', '1');
        metric('demo', 'Total', '1');
        expect(find.text('Datos de demostración'), findsOneWidget);
        await reveal(tester, find.byType(DropdownButtonFormField<String>));
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await settle(tester);
        await tester.tap(find.text('Basura y acumulación de residuos').last);
        await settle(tester);
        metric('local', 'Total', '0');
        metric('demo', 'Total', '1');
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Reportes'),
        );
        await settle(tester);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'avenida',
        );
        await reportListReady(tester);
        expect(find.text('Bache en avenida'), findsOneWidget);
        expect(find.text('Basura de demostración'), findsNothing);
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Estadísticas'),
        );
        await settle(tester);
        await reveal(tester, find.byKey(const ValueKey('local:Total')));
        metric('local', 'Total', '0');
        metric('demo', 'Total', '1');
        await reveal(tester, find.text('Limpiar filtros de estadísticas'));
        await tester.tap(find.text('Limpiar filtros de estadísticas'));
        await settle(tester);
        metric('local', 'Total', '1');
        expect(find.byKey(const ValueKey('demo:Total')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await tester.runAsync(f.db.close);
      }
    },
  );

  testWidgets(
    'date selection uses local calendar days, filters creation and clears the range',
    (tester) async {
      final f = LocalFixture();
      final filters = StatisticsFilterCubit();
      await tester.runAsync(() async {
        await f.initialize();
        await f.reports.create(f.draft());
      });
      final repo = SqliteStatisticsRepository(
        f.db,
        ticks: () => const Stream.empty(),
      );
      try {
        await tester.pumpWidget(page(f, repo, filters));
        await settle(tester);
        await tester.tap(find.text('Elegir fechas de creación'));
        await settle(tester);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await settle(tester);
        await tester.enterText(find.byType(TextField).at(0), '01/11/2026');
        await tester.enterText(find.byType(TextField).at(1), '30/11/2026');
        await tester.tap(find.text('Aplicar fechas'));
        await settle(tester);
        expect(filters.state.from, DateTime(2026, 11, 1).toUtc());
        expect(filters.state.until, DateTime(2026, 12, 1).toUtc());
        metric('local', 'Total', '1');
        filters.dates(DateTime.utc(2027), DateTime.utc(2028));
        await settle(tester);
        metric('local', 'Total', '0');
        await tester.tap(find.text('Quitar fechas'));
        await settle(tester);
        metric('local', 'Total', '1');
        expect(filters.state.from, isNull);
        expect(filters.state.until, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await filters.close();
        await tester.runAsync(f.db.close);
      }
    },
  );

  testWidgets(
    'retry handles query errors; changing filters hides old results until the new query arrives',
    (tester) async {
      final f = LocalFixture();
      final filters = StatisticsFilterCubit();
      final repo = ControlledStatistics();
      await tester.runAsync(
        () => f.db.customSelect('SELECT * FROM categories').get(),
      );
      try {
        await tester.pumpWidget(page(f, repo, filters));
        await tester.pump();
        repo.sources.single.addError(StateError('read failed'));
        await settle(tester);
        await reveal(tester, find.text('Reintentar estadísticas'));
        await tester.tap(find.text('Reintentar estadísticas'));
        await tester.pump();
        repo.sources.last.add(sample(3));
        await settle(tester);
        metric('local', 'Total', '3');
        filters.category('baches');
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('local:Total')), findsNothing);
        repo.sources.last.add(sample(0));
        await settle(tester);
        metric('local', 'Total', '0');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await tester.runAsync(repo.close);
        await filters.close();
        await tester.runAsync(f.db.close);
      }
    },
  );

  testWidgets(
    'statistics fit narrow screen and enlarged text, expose time units and refresh ages on ticks',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = LocalFixture();
      final filters = StatisticsFilterCubit();
      final ticks = StreamController<void>();
      final created = DateTime.utc(2026, 11, 19, 12);
      var now = created.add(const Duration(hours: 2));
      await tester.runAsync(() async {
        await f.initialize();
        await f.reports.create(f.draft());
      });
      final repo = SqliteStatisticsRepository(
        f.db,
        clock: () => now,
        ticks: () => ticks.stream,
      );
      try {
        await tester.pumpWidget(
          page(f, repo, filters, textScaler: const TextScaler.linear(2)),
        );
        await settle(tester);
        await reveal(tester, find.text('Antigüedad media de pendientes'));
        expect(find.text('2 h 0 min'), findsWidgets);
        expect(find.text('Sin reportes solucionados'), findsOneWidget);
        now = now.add(const Duration(hours: 1));
        ticks.add(null);
        await settle(tester);
        expect(find.text('3 h 0 min'), findsWidgets);
        await reveal(tester, find.text('Baches y daños en las calles: 1'));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await tester.runAsync(ticks.close);
        await filters.close();
        await tester.runAsync(f.db.close);
      }
    },
  );
}
