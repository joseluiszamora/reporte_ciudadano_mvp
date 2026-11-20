import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class LocalPhotoReader {
  Future<File?> open(String relativePath);
}

class PrivatePhotoReader implements LocalPhotoReader {
  PrivatePhotoReader({Future<Directory> Function()? directory})
    : directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() directory;
  @override
  Future<File?> open(String relativePath) async {
    if (relativePath.isEmpty ||
        relativePath.startsWith('/') ||
        relativePath.contains('\\') ||
        relativePath.contains(':') ||
        relativePath
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    try {
      final root = await directory();
      final file = File('${root.path}${Platform.pathSeparator}$relativePath');
      if (!await file.exists()) return null;
      final rootPath = await root.resolveSymbolicLinks();
      final resolved = await file.resolveSymbolicLinks();
      final prefix = '$rootPath${Platform.pathSeparator}';
      final inside = Platform.isWindows
          ? resolved.toLowerCase().startsWith(prefix.toLowerCase())
          : resolved.startsWith(prefix);
      return inside ? File(resolved) : null;
    } catch (_) {
      return null;
    }
  }
}
