import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/report_composition.dart';

abstract interface class ReportDraftStore {
  Future<ReportComposition?> load(String uid);
  Future<void> save(String uid, ReportComposition draft);
  Future<void> delete(String uid);
  Future<String?> pendingOwner();
  Future<void> markPicker(String uid);
  Future<void> clearPicker(String uid);
}

class PrivateReportDraftStore implements ReportDraftStore {
  PrivateReportDraftStore({Future<Directory> Function()? directory})
    : directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() directory;
  Future<void> _tail = Future.value();
  Future<T> exclusive<T>(Future<T> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<File> file(String uid) async => File(
    '${(await directory()).path}/drafts/${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}.json',
  );
  Future<File> marker() async =>
      File('${(await directory()).path}/drafts/pending-picker.json');
  Future<void> write(File target, String content) async {
    await target.parent.create(recursive: true);
    final pending = File('${target.path}.part');
    await pending.writeAsString(content, flush: true);
    await pending.rename(target.path);
  }

  @override
  Future<ReportComposition?> load(String uid) => exclusive(() async {
    final target = await file(uid);
    if (!await target.exists()) return null;
    return ReportComposition.fromJson(
      jsonDecode(await target.readAsString()) as Map<String, dynamic>,
    );
  });

  @override
  Future<void> save(String uid, ReportComposition draft) =>
      exclusive(() async => write(await file(uid), jsonEncode(draft.toJson())));
  @override
  Future<void> delete(String uid) => exclusive(() async {
    final target = await file(uid);
    if (await target.exists()) await target.delete();
  });

  @override
  Future<String?> pendingOwner() => exclusive(_pendingOwner);
  Future<String?> _pendingOwner() async {
    final target = await marker();
    return await target.exists()
        ? jsonDecode(await target.readAsString())['uid'] as String
        : null;
  }

  @override
  Future<void> markPicker(String uid) =>
      exclusive(() async => write(await marker(), jsonEncode({'uid': uid})));
  @override
  Future<void> clearPicker(String uid) => exclusive(() async {
    if (await _pendingOwner() == uid) await (await marker()).delete();
  });
}
