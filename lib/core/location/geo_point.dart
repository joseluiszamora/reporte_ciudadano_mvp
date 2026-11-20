import 'dart:math' as math;

import '../validation/input_limits.dart';

class GeoPoint {
  factory GeoPoint(double latitude, double longitude) {
    if (!InputLimits.validCoordinates(latitude, longitude)) {
      throw ArgumentError('Coordenadas no válidas.');
    }
    return GeoPoint._(latitude, longitude);
  }
  const GeoPoint._(this.latitude, this.longitude);
  static const elAlto = GeoPoint._(-16.5, -68.15);
  final double latitude;
  final double longitude;
  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  double distanceTo(GeoPoint other) {
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(other.latitude - latitude);
    final dLon = radians(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(latitude)) *
            math.cos(radians(other.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  bool get isFarFromElAlto => distanceTo(elAlto) > 30000;
  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      latitude == other.latitude &&
      longitude == other.longitude;
  @override
  int get hashCode => Object.hash(latitude, longitude);
}
