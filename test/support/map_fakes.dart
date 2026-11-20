import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:reporte_ciudadano_mvp/core/location/geo_point.dart';
import 'package:reporte_ciudadano_mvp/core/location/location_gateway.dart';
import 'package:reporte_ciudadano_mvp/features/map/domain/map_report_repository.dart';

class TestTiles extends TileProvider {
  TestTiles({this.fail = false});
  final bool fail;
  static final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(fail ? bytes.sublist(0, 4) : bytes);
}

class TestLocation implements LocationGateway {
  int calls = 0;
  bool? openedAppSettings;
  LocationFailure? failure;
  @override
  Future<GeoPoint> locate() async {
    calls++;
    if (failure != null) throw LocationException(failure!);
    return GeoPoint(-16.51, -68.16);
  }

  @override
  Future<bool> openSettings({required bool appSettings}) async {
    openedAppSettings = appSettings;
    return true;
  }
}

class TestMapReports implements MapReportRepository {
  TestMapReports([this.markers = const []]);
  final List<MapReport> markers;
  @override
  Stream<List<MapReport>> watchMarkers() => Stream.value(markers);
}
