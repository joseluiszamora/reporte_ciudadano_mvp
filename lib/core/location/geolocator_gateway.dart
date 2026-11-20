import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'geo_point.dart';
import 'location_gateway.dart';

class GeolocatorGateway implements LocationGateway {
  @override
  Future<GeoPoint> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(LocationFailure.disabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(LocationFailure.deniedForever);
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const LocationException(LocationFailure.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.disabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationFailure.denied);
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Future<bool> openSettings({required bool appSettings}) => appSettings
      ? Geolocator.openAppSettings()
      : Geolocator.openLocationSettings();
}
