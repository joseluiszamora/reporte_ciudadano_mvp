import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_read_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/presentation/report_detail_page.dart';

import '../support/local_fixture.dart';
import '../support/map_fakes.dart';
import 'report_browsing_test.dart' show MissingPhotos;

void main() {
  testWidgets(
    'share previews anonymous demo data, requires confirmation and blocks deleted reports',
    (tester) async {
      final fixture = LocalFixture();
      final id = (await tester.runAsync(() async {
        await fixture.initialize();
        final id = await fixture.reports.create(fixture.draft());
        await fixture.db.customStatement(
          'UPDATE reports SET is_demo=1 WHERE id=?',
          [id],
        );
        return id;
      }))!;
      const channel = MethodChannel('bo.elalto.reports/share');
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ReportDetailPage(
              id: id,
              repository: SqliteReportReadRepository(fixture.db),
              photos: MissingPhotos(),
              tiles: TestTiles.new,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        Future<void> preview() async {
          await tester.tap(
            find.widgetWithText(OutlinedButton, 'Compartir resumen'),
          );
          await tester.pumpAndSettle();
        }

        Future<void> confirmUntil(bool Function() done) async {
          await tester.tap(find.text('Compartir'));
          for (var step = 0; step < 50 && !done(); step++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
          }
          await tester.pumpAndSettle();
        }

        await preview();
        expect(calls, isEmpty);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        await preview();
        await confirmUntil(() => calls.isNotEmpty);
        expect(calls.single.method, 'shareText');
        final summary = calls.single.arguments['text'] as String;
        expect(summary, contains('Reporte de demostración'));
        expect(summary, contains('Autor: Ciudadano anónimo'));
        expect(summary, contains('Ubicación: -16.500000, -68.150000'));
        for (final privateValue in [
          id,
          'private@example.test',
          'photos/a.jpg',
          'Vecina',
          '/reporte/',
          'https://',
        ]) {
          expect(summary, isNot(contains(privateValue)));
        }
        await preview();
        await fixture.reports.softDelete(
          reportId: id,
          reason: 'Se elimina el duplicado',
        );
        await confirmUntil(
          () => find.textContaining('El reporte cambió').evaluate().isNotEmpty,
        );
        expect(calls, hasLength(1));
        expect(find.textContaining('El reporte cambió'), findsOneWidget);
      } finally {
        semantics.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.db.close);
      }
    },
  );
}
