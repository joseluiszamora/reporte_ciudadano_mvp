import 'package:flutter_map/flutter_map.dart';

/// Separate factory: each mounted layer owns and disposes its provider.
typedef TileProviderFactory = TileProvider Function();

abstract final class MapTiles {
  static const url = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent =
      'ReportesCiudadanosElAlto/1.0 (+https://github.com/joseluiszamora/reporte_ciudadano_mvp)';
  static TileProvider create() => NetworkTileProvider(
    headers: {'User-Agent': userAgent},
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 200 * 1024 * 1024,
    ),
  );
}
