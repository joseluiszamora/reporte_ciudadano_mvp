import 'geo_point.dart';

enum LocationFailure { denied, deniedForever, disabled, timeout, unavailable }

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
  String get message => switch (failure) {
    LocationFailure.denied => 'No se concedió acceso a tu ubicación. Puedes elegir el punto manualmente.',
    LocationFailure.deniedForever => 'El permiso de ubicación está bloqueado. Puedes habilitarlo en los ajustes o elegir el punto manualmente.',
    LocationFailure.disabled => 'La ubicación del dispositivo está desactivada. Puedes activarla o elegir el punto manualmente.',
    LocationFailure.timeout => 'No se obtuvo una ubicación a tiempo. Reintenta o elige el punto manualmente.',
    LocationFailure.unavailable =>
      'No se pudo obtener tu ubicación. Puedes elegir el punto manualmente.',
  };
  @override
  String toString() => message;
}

abstract interface class LocationGateway {
  /// Explicit user request only. Never call automatically on page entry.
  Future<GeoPoint> locate();
  Future<bool> openSettings({required bool appSettings});
}
