import 'package:image_picker/image_picker.dart';

import 'photo_storage.dart';

abstract interface class PhotoSelection {
  Future<List<String>> pick({required bool camera, required int remaining});
  Future<List<String>> recover();
}

class AndroidPhotoSelection implements PhotoSelection {
  AndroidPhotoSelection() {
    lost = _recover();
  }
  final picker = ImagePicker();
  late Future<List<String>> lost;
  bool recoveryFailed = false;
  Future<List<String>> _recover() async {
    try {
      final response = await picker.retrieveLostData();
      if (response.exception != null) recoveryFailed = true;
      return response.files?.map((file) => file.path).toList() ?? [];
    } catch (_) {
      recoveryFailed = true;
      return [];
    }
  }

  @override
  Future<List<String>> recover() async {
    final paths = await lost;
    lost = Future.value([]);
    if (recoveryFailed) {
      recoveryFailed = false;
      throw const PhotoStorageException();
    }
    return paths;
  }

  @override
  Future<List<String>> pick({
    required bool camera,
    required int remaining,
  }) async {
    try {
      if (camera || remaining == 1) {
        final file = await picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 95,
          requestFullMetadata: false,
        );
        return file == null ? [] : [file.path];
      }
      return (await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
        limit: remaining,
        requestFullMetadata: false,
      )).map((file) => file.path).toList();
    } catch (_) {
      throw const PhotoStorageException();
    }
  }
}
