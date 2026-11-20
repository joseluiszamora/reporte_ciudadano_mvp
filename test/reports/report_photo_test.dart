import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/core/media/local_photo_reader.dart';
import 'package:reporte_ciudadano_mvp/features/reports/presentation/report_photo.dart';

import '../support/map_fakes.dart';

class ReadyPhotoReader implements LocalPhotoReader {
  ReadyPhotoReader(this.file);
  final File file;
  @override
  Future<File?> open(String relativePath) async => file;
}

void main() {
  testWidgets('private photo opens an interactive full screen viewer', (
    tester,
  ) async {
    late Directory root;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('citizen_photo_view_');
      await File('${root.path}/photo.png').writeAsBytes(TestTiles.bytes);
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 240,
              child: ReportPhoto(
                path: 'photo.png',
                reader: ReadyPhotoReader(File('${root.path}/photo.png')),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.text('Fotografía'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });
}
