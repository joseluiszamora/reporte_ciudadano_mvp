import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/location/geo_point.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/presentation/report_composer_cubit.dart';

import '../support/local_fixture.dart';
import '../support/composer_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalFixture fixture;
  late MemoryDrafts drafts;
  late MemoryPhotos photos;
  late QueuePhotos picker;
  late SqliteReportRepository reports;
  late ReportComposerCubit composer;
  setUp(() async {
    fixture = LocalFixture();
    await fixture.initialize();
    drafts = MemoryDrafts();
    photos = MemoryPhotos();
    picker = QueuePhotos();
    reports = SqliteReportRepository(fixture.db, fixture.session, photos);
    composer = ReportComposerCubit(
      uid: 'owner',
      currentUid: () => fixture.uid,
      reports: reports,
      storage: photos,
      selection: picker,
      drafts: drafts,
    );
    await composer.initialize();
  });
  tearDown(() async {
    await composer.close();
    await fixture.db.close();
  });
  void fill() => composer.update(
    composer.state.draft.copy(
      categoryId: 'baches',
      title: 'Bache en avenida principal',
      description: 'Un bache dificulta el paso de vehículos.',
      point: GeoPoint.elAlto,
    ),
  );

  test('required fields prevent preview and no report is written before confirmation', () async {
    expect(await composer.preview(), isFalse);
    fill();
    expect(await composer.preview(), isFalse);
    picker.next = ['source'];
    await composer.pick(camera: false);
    expect(await composer.preview(), isTrue);
    expect(
      await fixture.db.customSelect('SELECT * FROM reports').get(),
      isEmpty,
    );
  });
  test('failed photo import preserves text, prompts reattachment and does not write report', () async {
    fill();
    photos.fail = true;
    picker.next = ['bad'];
    await composer.pick(camera: true);
    expect(composer.state.draft.title, 'Bache en avenida principal');
    expect(composer.state.draft.photos, isEmpty);
    expect(composer.state.message, contains('Vuelve a adjuntarla'));
    await composer.submit();
    expect(
      await fixture.db.customSelect('SELECT * FROM reports').get(),
      isEmpty,
    );
  });
  test(
    'preview save is atomic and duplicate submit/retry creates one report',
    () async {
      fill();
      picker.next = ['source'];
      await composer.pick(camera: true);
      final draft = composer.state.draft.toReport();
      final one = composer.submit();
      final two = composer.submit();
      await Future.wait([one, two]);
      final id = composer.state.savedId!;
      expect(await reports.create(draft), id);
      expect(
        await fixture.db.customSelect('SELECT * FROM reports').get(),
        hasLength(1),
      );
      expect(
        await fixture.db
            .customSelect(
              "SELECT * FROM audit_events WHERE action='REPORT_CREATED'",
            )
            .get(),
        hasLength(1),
      );
      expect(drafts.drafts['owner'], isNull);
      expect((await reports.getReport(id))!.publicAuthor, 'Ciudadano anónimo');
    },
  );
  test(
    'SQL audit failure preserves draft and photos for a successful retry',
    () async {
      fill();
      picker.next = ['source'];
      await composer.pick(camera: true);
      await fixture.db.customStatement(
        "CREATE TRIGGER reject_creation BEFORE INSERT ON audit_events WHEN NEW.action='REPORT_CREATED' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await composer.submit();
      expect(composer.state.savedId, isNull);
      expect(drafts.drafts['owner']!.photos, hasLength(1));
      expect(photos.paths, hasLength(1));
      expect(
        await fixture.db.customSelect('SELECT * FROM reports').get(),
        isEmpty,
      );
      await fixture.db.customStatement('DROP TRIGGER reject_creation');
      await composer.submit();
      expect(composer.state.savedId, isNotNull);
    },
  );
  test('missing photo or changed session blocks final save', () async {
    fill();
    picker.next = ['source'];
    await composer.pick(camera: false);
    photos.paths.clear();
    await composer.submit();
    expect(composer.state.message, contains('Vuelve a adjuntarla'));
    fixture.uid = null;
    await composer.submit();
    expect(
      await fixture.db.customSelect('SELECT * FROM reports').get(),
      isEmpty,
    );
  });
  test(
    'draft survives controller restart and recovery is bound to its account',
    () async {
      fill();
      await composer.flush();
      final request = composer.state.draft.requestId;
      drafts.pending = 'other';
      picker.recovered = ['lost'];
      await composer.close();
      composer = ReportComposerCubit(
        uid: 'owner',
        currentUid: () => fixture.uid,
        reports: reports,
        storage: photos,
        selection: picker,
        drafts: drafts,
      );
      await composer.initialize();
      expect(composer.state.draft.requestId, request);
      expect(picker.recoveries, 0);
      drafts.pending = 'owner';
      await composer.close();
      composer = ReportComposerCubit(
        uid: 'owner',
        currentUid: () => fixture.uid,
        reports: reports,
        storage: photos,
        selection: picker,
        drafts: drafts,
      );
      await composer.initialize();
      expect(picker.recoveries, 1);
      expect(composer.state.draft.photos, hasLength(1));
      expect(drafts.pending, isNull);
    },
  );
  test('interrupted cleanup after commit resumes the existing report without duplication', () async {
    fill();
    picker.next = ['source'];
    await composer.pick(camera: true);
    drafts.failDelete = true;
    await composer.submit();
    final id = composer.state.savedId!;
    await composer.close();
    composer = ReportComposerCubit(
      uid: 'owner',
      currentUid: () => fixture.uid,
      reports: reports,
      storage: photos,
      selection: picker,
      drafts: drafts,
    );
    await composer.initialize();
    expect(composer.state.savedId, id);
    expect(
      await fixture.db.customSelect('SELECT * FROM reports').get(),
      hasLength(1),
    );
  });
  test('photo cap and explicit discard remove only the unsent draft', () async {
    fill();
    picker.next = List.generate(7, (index) => 'source$index');
    await composer.pick(camera: false);
    expect(composer.state.draft.photos, hasLength(5));
    await composer.removePhoto(0);
    expect(composer.state.draft.photos, hasLength(4));
    await composer.discard();
    expect(composer.state.draft.hasContent, isFalse);
    expect(photos.paths, isEmpty);
    expect(
      await fixture.db.customSelect('SELECT * FROM reports').get(),
      isEmpty,
    );
  });
}
