import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:reporte_ciudadano_mvp/core/location/geo_point.dart';
import 'package:reporte_ciudadano_mvp/core/location/geolocator_gateway.dart';
import 'package:reporte_ciudadano_mvp/core/location/location_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/map/presentation/location_cubit.dart';

import '../support/map_fakes.dart';

class PendingLocation extends TestLocation {
  final result = Completer<GeoPoint>();
  @override
  Future<GeoPoint> locate() => result.future;
}

class TestGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requested = LocationPermission.denied;
  int requests = 0;
  int fixes = 0;
  bool timeout = false;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    if (timeout) throw TimeoutException('No GPS');
    return Position(
      latitude: -16.5,
      longitude: -68.15,
      timestamp: DateTime.utc(2026),
      accuracy: 50,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Matcher locationError(LocationFailure failure) =>
    isA<LocationException>().having((e) => e.failure, 'failure', failure);

void main() {
  test(
    'coordinates reject invalid numbers and warn outside approximate area',
    () {
      expect(() => GeoPoint(double.nan, 0), throwsArgumentError);
      expect(() => GeoPoint(0, double.infinity), throwsArgumentError);
      expect(() => GeoPoint(91, 0), throwsArgumentError);
      expect(GeoPoint.elAlto.distanceTo(GeoPoint.elAlto), 0);
      expect(GeoPoint(-16.51, -68.16).isFarFromElAlto, isFalse);
      expect(GeoPoint(0, 0).isFarFromElAlto, isTrue);
    },
  );
  test('location is explicit, denial preserves selection and manual point clears error', () async {
    final gateway = TestLocation()..failure = LocationFailure.denied;
    final cubit = LocationCubit(gateway, initial: GeoPoint.elAlto);
    expect(gateway.calls, 0);
    await cubit.locate();
    expect(cubit.state.failure, LocationFailure.denied);
    expect(cubit.state.point, GeoPoint.elAlto);
    cubit.selectManual(GeoPoint(-16.6, -68.2));
    expect(cubit.state.failure, isNull);
    expect(cubit.state.point, GeoPoint(-16.6, -68.2));
    await cubit.close();
  });
  test('manual correction wins over a slow GPS result', () async {
    final gateway = PendingLocation();
    final cubit = LocationCubit(gateway);
    final pending = cubit.locate();
    cubit.selectManual(GeoPoint.elAlto);
    gateway.result.complete(GeoPoint(0, 0));
    await pending;
    expect(cubit.state.point, GeoPoint.elAlto);
    expect(cubit.state.busy, isFalse);
    await cubit.close();
  });
  test('requesting the same GPS point still advances camera focus', () async {
    final cubit = LocationCubit(
      TestLocation(),
      initial: GeoPoint(-16.51, -68.16),
    );
    await cubit.locate();
    expect(cubit.state.focusRevision, 1);
    await cubit.locate();
    expect(cubit.state.focusRevision, 2);
    await cubit.close();
  });
  test('closing picker while GPS pending ignores late result', () async {
    final gateway = PendingLocation();
    final cubit = LocationCubit(gateway);
    final pending = cubit.locate();
    await cubit.close();
    gateway.result.complete(GeoPoint.elAlto);
    await pending;
  });

  group('native gateway permission flow', () {
    late GeolocatorPlatform previous;
    late TestGeolocator platform;
    setUp(() {
      previous = GeolocatorPlatform.instance;
      platform = TestGeolocator();
      GeolocatorPlatform.instance = platform;
    });
    tearDown(() => GeolocatorPlatform.instance = previous);
    test('denied request does not fetch position', () async {
      await expectLater(
        GeolocatorGateway().locate(),
        throwsA(locationError(LocationFailure.denied)),
      );
      expect(platform.requests, 1);
      expect(platform.fixes, 0);
    });
    test('permanent denial does not request again', () async {
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        GeolocatorGateway().locate(),
        throwsA(locationError(LocationFailure.deniedForever)),
      );
      expect(platform.requests, 0);
      expect(platform.fixes, 0);
    });
    test('disabled service does not request permission', () async {
      platform.enabled = false;
      await expectLater(
        GeolocatorGateway().locate(),
        throwsA(locationError(LocationFailure.disabled)),
      );
      expect(platform.requests, 0);
    });
    test('permission granted returns coordinates and maps timeout to recoverable error', () async {
      platform.requested = LocationPermission.whileInUse;
      expect(await GeolocatorGateway().locate(), GeoPoint.elAlto);
      platform.timeout = true;
      await expectLater(
        GeolocatorGateway().locate(),
        throwsA(locationError(LocationFailure.timeout)),
      );
    });
  });
}
