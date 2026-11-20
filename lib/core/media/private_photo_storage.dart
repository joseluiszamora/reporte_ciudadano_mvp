import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../validation/input_limits.dart';
import 'local_photo_reader.dart';
import 'photo_storage.dart';

Uint8List normalizeReportPhoto(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder is! img.JpegDecoder &&
      decoder is! img.PngDecoder &&
      decoder is! img.WebPDecoder) {
    throw const PhotoStorageException();
  }
  final info = decoder!.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 20000000) {
    throw const PhotoStorageException();
  }
  var photo = decoder.decodeFrame(0);
  if (photo == null) throw const PhotoStorageException();
  photo = img.bakeOrientation(photo);
  if (photo.width > 2048 || photo.height > 2048) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: 2048)
        : img.copyResize(photo, height: 2048);
  }
  // Copy pixels onto a new RGB image; EXIF, GPS, comments and profiles do not follow.
  final clean = img.Image(
    width: photo.width,
    height: photo.height,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, photo);
  return img.encodeJpg(clean, quality: 85);
}

class PrivatePhotoStorage implements PhotoStorage {
  PrivatePhotoStorage({
    Future<Directory> Function()? directory,
    Future<bool> Function(String)? referenced,
  }) : directory = directory ?? getApplicationDocumentsDirectory,
       referenced = referenced ?? _unused;
  static Future<bool> _unused(String _) async => false;
  final Future<Directory> Function() directory;
  final Future<bool> Function(String) referenced;
  @override
  Future<StoredPhoto> import(String sourcePath) async {
    File? pending;
    File? destination;
    try {
      final source = File(sourcePath);
      final size = await source.length();
      if (size < 1 || size > InputLimits.maxPhotoBytes) {
        throw const PhotoStorageException();
      }
      final result = await compute(
        normalizeReportPhoto,
        await source.readAsBytes(),
      );
      if (result.isEmpty || result.length > InputLimits.maxPhotoBytes) {
        throw const PhotoStorageException();
      }
      final root = await directory();
      final photos = Directory('${root.path}/photos');
      await photos.create(recursive: true);
      final rootPath = await root.resolveSymbolicLinks();
      final photoPath = await photos.resolveSymbolicLinks();
      if (photoPath != '$rootPath${Platform.pathSeparator}photos') {
        throw const PhotoStorageException();
      }
      final relative = 'photos/${const Uuid().v4()}.jpg';
      destination = File('${root.path}/$relative');
      pending = File('${destination.path}.part');
      await pending.writeAsBytes(result, flush: true);
      if (await pending.length() != result.length ||
          !listEquals(await pending.readAsBytes(), result)) {
        throw const PhotoStorageException();
      }
      await pending.rename(destination.path);
      return StoredPhoto(
        relativePath: relative,
        mimeType: 'image/jpeg',
        bytes: result.length,
      );
    } catch (_) {
      for (final file in [pending, destination]) {
        try {
          if (file != null && await file.exists()) await file.delete();
        } catch (_) {
          /* Never delete the user's source. */
        }
      }
      throw const PhotoStorageException();
    }
  }

  @override
  Future<bool> exists(String path) async =>
      await PrivatePhotoReader(directory: directory).open(path) != null;
  @override
  Future<void> remove(String path) async {
    if (await referenced(path)) return;
    final file = await PrivatePhotoReader(directory: directory).open(path);
    if (file != null) await file.delete();
  }
}
