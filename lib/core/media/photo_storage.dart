class StoredPhoto {
  const StoredPhoto({
    required this.relativePath,
    required this.mimeType,
    required this.bytes,
  });
  final String relativePath;
  final String mimeType;
  final int bytes;
}

abstract interface class PhotoStorage {
  /// Copy to persistent private storage and verify before returning.
  /// On failure throw PhotoStorageException and do not save the report.
  Future<StoredPhoto> import(String sourcePath);
  Future<bool> exists(String relativePath);
  Future<void> remove(String relativePath);
}

class PhotoStorageException implements Exception {
  const PhotoStorageException();
  String get message =>
      'No se pudo guardar la fotografía. Vuelve a adjuntarla.';
  @override
  String toString() => message;
}
