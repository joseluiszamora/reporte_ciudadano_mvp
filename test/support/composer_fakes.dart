import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_selection.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/report_draft_store.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_composition.dart';

class MemoryDrafts implements ReportDraftStore {
  final drafts = <String, ReportComposition>{};
  String? pending;
  bool failSave = false;
  bool failDelete = false;
  @override
  Future<ReportComposition?> load(String uid) async => drafts[uid];
  @override
  Future<void> save(String uid, ReportComposition draft) async {
    if (failSave) throw StateError('test storage failure');
    drafts[uid] = draft;
  }

  @override
  Future<void> delete(String uid) async {
    if (failDelete) throw StateError('test delete failure');
    drafts.remove(uid);
  }

  @override
  Future<String?> pendingOwner() async => pending;
  @override
  Future<void> markPicker(String uid) async => pending = uid;
  @override
  Future<void> clearPicker(String uid) async {
    if (pending == uid) pending = null;
  }
}

class MemoryPhotos implements PhotoStorage {
  final paths = <String>{};
  bool fail = false;
  int sequence = 0;
  @override
  Future<StoredPhoto> import(String sourcePath) async {
    if (fail) throw const PhotoStorageException();
    final path = 'photos/import-${++sequence}.jpg';
    paths.add(path);
    return StoredPhoto(relativePath: path, mimeType: 'image/jpeg', bytes: 100);
  }

  @override
  Future<bool> exists(String path) async => paths.contains(path);
  @override
  Future<void> remove(String path) async => paths.remove(path);
}

class QueuePhotos implements PhotoSelection {
  List<String> next = [];
  List<String> recovered = [];
  int picks = 0;
  int recoveries = 0;
  @override
  Future<List<String>> pick({
    required bool camera,
    required int remaining,
  }) async {
    picks++;
    return next;
  }

  @override
  Future<List<String>> recover() async {
    recoveries++;
    return recovered;
  }
}
