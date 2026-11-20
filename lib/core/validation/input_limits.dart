abstract final class InputLimits {
  static const nameMin = 2;
  static const nameMax = 50;
  static const titleMin = 10;
  static const titleMax = 100;
  static const descriptionMin = 20;
  static const descriptionMax = 2000;
  static const noteMin = 10;
  static const noteMax = 1000;
  static const maxPhotos = 5;
  static const maxPhotoBytes = 10 * 1024 * 1024;
  static const photoMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  static String? text(String value, {required int min, required int max}) {
    final length = value.trim().runes.length;
    return length < min || length > max
        ? 'Introduce entre $min y $max caracteres.'
        : null;
  }

  static bool validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
