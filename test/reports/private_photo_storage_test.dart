import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reporte_ciudadano_mvp/core/media/private_photo_storage.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/report_draft_store.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_composition.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('citizen_import_'),
  );
  tearDown(() async => root.delete(recursive: true));
  test('photo is decoded, oriented, metadata stripped and retained after source deletion', () async {
    final photo = img.Image(width: 20, height: 10);
    photo.exif.imageIfd.orientation = 6;
    photo.exif.imageIfd.imageDescription = 'Private camera metadata';
    final source = File('${root.path}/source.jpg');
    await source.writeAsBytes(img.encodeJpg(photo));
    final storage = PrivatePhotoStorage(directory: () async => root);
    final imported = await storage.import(source.path);
    await source.delete();
    expect(imported.mimeType, 'image/jpeg');
    expect(await storage.exists(imported.relativePath), isTrue);
    final decoded = img.decodeJpg(
      await File('${root.path}/${imported.relativePath}').readAsBytes(),
    )!;
    expect(decoded.width, 10);
    expect(decoded.height, 20);
    expect(decoded.exif.imageIfd.imageDescription, isNull);
    expect(decoded.exif.imageIfd.orientation, isNot(6));
  });
  test(
    'rejects unreadable or invalid image and never deletes the original source',
    () async {
      final source = File('${root.path}/bad.jpg');
      await source.writeAsBytes([1, 2, 3]);
      final storage = PrivatePhotoStorage(directory: () async => root);
      await expectLater(
        storage.import(source.path),
        throwsA(isA<PhotoStorageException>()),
      );
      expect(await source.exists(), isTrue);
      await expectLater(
        storage.import('${root.path}/missing.jpg'),
        throwsA(isA<PhotoStorageException>()),
      );
    },
  );
  test('referenced photos cannot be deleted during draft cleanup', () async {
    final source = File('${root.path}/photo.png');
    await source.writeAsBytes(img.encodePng(img.Image(width: 2, height: 2)));
    final storage = PrivatePhotoStorage(
      directory: () async => root,
      referenced: (_) async => true,
    );
    final photo = await storage.import(source.path);
    await storage.remove(photo.relativePath);
    expect(await storage.exists(photo.relativePath), isTrue);
  });
  test('draft store is isolated by UID and survives reopening', () async {
    final store = PrivateReportDraftStore(directory: () async => root);
    final draft = ReportComposition(title: 'Texto de borrador');
    await store.save('uid/one', draft);
    await store.save('uid/one', draft.copy(title: 'Texto actualizado'));
    final reopened = PrivateReportDraftStore(directory: () async => root);
    expect((await reopened.load('uid/one'))!.title, 'Texto actualizado');
    expect(await reopened.load('other'), isNull);
    await store.markPicker('uid/one');
    await store.clearPicker('other');
    expect(await store.pendingOwner(), 'uid/one');
    await store.clearPicker('uid/one');
    expect(await store.pendingOwner(), isNull);
  });
}
