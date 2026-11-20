import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/core/media/private_photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/report_draft_store.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/report_media_references.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_composition.dart';

import '../support/local_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'photos resize to 2048 and a destination write failure preserves source',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'citizen_media_integrity_',
      );
      try {
        final source = File('${root.path}/source.png');
        await source.writeAsBytes(
          img.encodePng(img.Image(width: 2200, height: 20)),
        );
        final storage = PrivatePhotoStorage(directory: () async => root);
        final photo = await storage.import(source.path);
        final decoded = img.decodeJpg(
          await File('${root.path}/${photo.relativePath}').readAsBytes(),
        )!;
        expect(decoded.width, 2048);
        final blocked = await Directory('${root.path}/blocked').create();
        await File('${blocked.path}/photos')
            .writeAsString('block directory creation');
        await expectLater(
          PrivatePhotoStorage(directory: () async => blocked)
              .import(source.path),
          throwsA(isA<PhotoStorageException>()),
        );
        expect(await source.exists(), isTrue);
        expect(await File('${blocked.path}/photos').exists(), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test('cleanup respects current images, archived revisions and proposal evidence after soft delete', () async {
    final fixture = LocalFixture();
    await fixture.initialize();
    try {
      final id = await fixture.reports.create(fixture.draft());
      await fixture.reports.update(
        reportId: id,
        expectedRevision: 0,
        reason: 'Fotografía reemplazada',
        draft: fixture.draft(
          images: [
            const StoredPhoto(
              relativePath: 'photos/b.jpg',
              mimeType: 'image/jpeg',
              bytes: 100,
            ),
          ],
        ),
      );
      await fixture.db.customStatement(
        """INSERT INTO resolution_proposals(id,report_id,proposer_uid,note,evidence_image_path,created_at)
        VALUES('p',?,'owner','Evidencia de la solución','photos/evidence.jpg','2026-11-20T00:00:00.000Z')""",
        [id],
      );
      await fixture.reports.softDelete(
        reportId: id,
        reason: 'Reporte duplicado',
      );
      final refs = ReportMediaReferences(fixture.db);
      expect(await refs.contains('photos/a.jpg'), isTrue);
      expect(await refs.contains('photos/b.jpg'), isTrue);
      expect(await refs.contains('photos/evidence.jpg'), isTrue);
      expect(await refs.contains('photos/unused.jpg'), isFalse);
    } finally {
      await fixture.db.close();
    }
  });
  test(
    'draft reads wait for earlier queued writes and retain the latest state',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'citizen_draft_queue_',
      );
      try {
        final store = PrivateReportDraftStore(directory: () async => root);
        final draft = ReportComposition(title: 'Primero');
        final one = store.save('owner', draft);
        final two = store.save('owner', draft.copy(title: 'Segundo'));
        final read = store.load('owner');
        await Future.wait([one, two]);
        expect((await read)!.title, 'Segundo');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
