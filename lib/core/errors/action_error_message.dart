import '../media/photo_storage.dart';
import 'repository_exception.dart';

String actionErrorMessage(Object error) => switch (error) {
  RepositoryException e => e.message,
  PhotoStorageException e => e.message,
  _ =>
    'No se pudo completar la acción. Conserva los datos y vuelve a intentarlo.',
};
