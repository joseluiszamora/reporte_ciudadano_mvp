enum RepositoryError {
  unauthenticated,
  forbidden,
  invalidInput,
  notFound,
  conflict,
}

class RepositoryException implements Exception {
  const RepositoryException(this.code, this.message);
  final RepositoryError code;
  final String message;
  @override
  String toString() => message;
}
