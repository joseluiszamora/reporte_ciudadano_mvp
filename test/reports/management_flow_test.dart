import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/app/app.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/google_auth_repository.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/identity_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/report_media_references.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';

import '../support/auth_fakes.dart';
import '../support/composer_fakes.dart';
import '../support/local_fixture.dart';
import '../support/map_fakes.dart';
import 'report_browsing_test.dart' show MissingPhotos;

class ReferencedPhotos extends MemoryPhotos {
  ReferencedPhotos(this.references);
  final ReportMediaReferences references;
  @override
  Future<void> remove(String path) async {
    if (!await references.contains(path)) await super.remove(path);
  }
}

class ManagementHarness {
  final f = LocalFixture();
  late final gateway = TestIdentityGateway(
    current: const VerifiedIdentity(uid: 'owner'),
  );
  late final auth = GoogleAuthRepository(f.db, gateway);
  late final storage = ReferencedPhotos(ReportMediaReferences(f.db))
    ..paths.add('photos/a.jpg');
  final picker = QueuePhotos()..next = ['evidence'];
  late String id;
  Future<void> start(WidgetTester tester, {bool admin = false}) async {
    await tester.runAsync(() async {
      await f.initialize();
      id = await f.reports.create(f.draft());
      f.uid = 'admin';
      await f.users.recordGoogleSignIn(uid: 'admin');
      await f.users.completePublicName('Administración');
      f.uid = 'owner';
    });
    if (admin) {
      gateway.current = const VerifiedIdentity(uid: 'admin', isAdmin: true);
    }
    await tester.pumpWidget(
      CitizenReportsApp(
        database: f.db,
        authRepository: auth,
        photoStorage: storage,
        photoSelection: picker,
        draftStore: MemoryDrafts(),
        photos: MissingPhotos(),
        location: TestLocation(),
        tiles: TestTiles.new,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> manage(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Reportes'));
    await tester.pumpAndSettle();
    await showText(tester, 'Bache en avenida');
    await tester.tap(find.text('Bache en avenida'));
    await tester.pumpAndSettle();
    await showText(tester, 'Acciones y propuestas');
    await tester.tap(find.text('Acciones y propuestas'));
    await tester.pumpAndSettle();
    expect(find.text('Gestionar reporte'), findsOneWidget);
  }

  Future<void> close(WidgetTester tester) async {
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
    await tester.runAsync(f.db.close);
  }
}

Future<void> showText(WidgetTester tester, String text) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  for (
    var i = 0;
    i < 35 && find.text(text).hitTestable().evaluate().isEmpty;
    i++
  ) {
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(
      (position.pixels + 180).clamp(0.0, position.maxScrollExtent).toDouble(),
    );
    await tester.pumpAndSettle();
  }
  expect(
    find.text(text),
    findsWidgets,
    reason:
        'Visible texts: ${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).join(' | ')}',
  );
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
}

Future<void> reason(WidgetTester tester, String text) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Motivo obligatorio'),
    text,
  );
  await tester.tap(find.text('Confirmar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'citizen proposes without resolving; account change rebuilds permissions; admin approves, reopens and logically deletes',
    (tester) async {
      final h = ManagementHarness();
      try {
        await h.start(tester);
        await h.manage(tester);
        expect(find.text('Iniciar seguimiento'), findsNothing);
        await showText(tester, 'Nota de solución');
        await tester.enterText(
          find.widgetWithText(TextField, 'Nota de solución'),
          'La reparación del tramo está terminada.',
        );
        await showText(tester, 'Galería');
        await tester.tap(find.text('Galería'));
        await tester.pumpAndSettle();
        await showText(tester, 'Enviar propuesta');
        await tester.tap(find.text('Enviar propuesta'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => h.f.reports.getReport(h.id)))!.status,
          ReportStatus.reported,
        );
        expect(find.text('Enviar propuesta'), findsNothing);
        h.gateway.change(const VerifiedIdentity(uid: 'admin', isAdmin: true));
        for (var i = 0; i < 15 && h.auth.currentUser?.uid != 'admin'; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        await tester.pumpAndSettle();
        expect(h.auth.currentUser!.uid, 'admin');
        await showText(tester, 'Aprobar');
        await tester.tap(find.text('Aprobar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(
          find.text('Introduce entre 10 y 1000 caracteres.'),
          findsOneWidget,
        );
        await reason(tester, 'La evidencia muestra la reparación terminada');
        expect(
          (await tester.runAsync(() => h.f.reports.getReport(h.id)))!.status,
          ReportStatus.resolved,
        );
        await showText(tester, 'Reabrir reporte');
        await tester.tap(find.text('Reabrir reporte'));
        await tester.pumpAndSettle();
        await reason(tester, 'Se detectaron nuevos daños en el mismo lugar');
        expect(
          (await tester.runAsync(() => h.f.reports.getReport(h.id)))!
              .resolvedAt,
          isNull,
        );
        await showText(tester, 'Eliminar reporte');
        await tester.tap(find.text('Eliminar reporte'));
        await tester.pumpAndSettle();
        await reason(tester, 'Se elimina por duplicidad confirmada');
        expect(
          await tester.runAsync(() => h.f.reports.getReport(h.id)),
          isNull,
        );
        expect(
          await tester.runAsync(
            () =>
                h.f.db.customSelect('SELECT * FROM resolution_proposals').get(),
          ),
          hasLength(1),
        );
        expect(h.storage.paths, contains('photos/import-1.jpg'));
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'owner edits title and replaces photo with reason; history keeps old photo and new evidence remains referenced',
    (tester) async {
      final h = ManagementHarness();
      try {
        await h.start(tester);
        await h.manage(tester);
        await tester.tap(find.text('Editar reporte'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Título'),
          'Bache en la avenida principal',
        );
        await showText(tester, 'Galería');
        await tester.tap(find.text('Galería'));
        await tester.pumpAndSettle();
        await showText(tester, 'Quitar foto 1');
        await tester.tap(find.text('Quitar foto 1'));
        await tester.pumpAndSettle();
        await showText(tester, 'Motivo del cambio');
        await tester.enterText(
          find.widgetWithText(TextField, 'Motivo del cambio'),
          'Título preciso y fotografía actualizada',
        );
        await showText(tester, 'Guardar cambios');
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();
        expect(find.text('Gestionar reporte'), findsOneWidget);
        final detail = (await tester.runAsync(
          () => h.f.reports.getReport(h.id),
        ))!;
        expect(detail.title, 'Bache en la avenida principal');
        expect(detail.revision, 1);
        expect(detail.photos.single.relativePath, 'photos/import-1.jpg');
        expect(
          h.storage.paths,
          containsAll(['photos/a.jpg', 'photos/import-1.jpg']),
        );
        expect(
          await tester.runAsync(
            () => h.f.db
                .customSelect(
                  "SELECT * FROM audit_events WHERE action='PHOTO_REPLACED'",
                )
                .get(),
          ),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );

  testWidgets(
    'admin queries and exports deleted report actions; changing to citizen removes private report',
    (tester) async {
      final h = ManagementHarness();
      try {
        await h.start(tester, admin: true);
        await tester.runAsync(
          () => h.f.reports.softDelete(
            reportId: h.id,
            reason: 'Duplicado para comprobación de auditoría',
          ),
        );
        await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
        await tester.pumpAndSettle();
        await showText(tester, 'Informe de acciones');
        await tester.tap(find.text('Informe de acciones'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Acción (ej. REPORT_DELETED)'),
          'REPORT_DELETED',
        );
        await showText(tester, 'Consultar acciones');
        await tester.tap(find.text('Consultar acciones'));
        await tester.pumpAndSettle();
        await showText(tester, 'Exportar resultados como CSV');
        await tester.tap(find.text('Exportar resultados como CSV'));
        await tester.pumpAndSettle();
        await showText(tester, 'Copiar CSV');
        expect(find.text('1 eventos encontrados'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                (widget.data?.contains('REPORT_DELETED') ?? false),
          ),
          findsOneWidget,
        );
        h.gateway.change(const VerifiedIdentity(uid: 'owner'));
        for (var i = 0; i < 15 && h.auth.currentUser?.uid != 'owner'; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Exportar resultados como CSV'), findsNothing);
        expect(
          find.text('Esta pantalla requiere permisos de administrador.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
}
