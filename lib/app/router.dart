import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/project_shell.dart';
import '../features/categories/domain/category_repository.dart';
import '../features/categories/presentation/category_catalog.dart';
import '../core/location/location_gateway.dart';
import '../features/map/domain/map_report_repository.dart';
import '../features/map/presentation/city_map_page.dart';
import '../features/map/presentation/map_tiles.dart';

GoRouter createAppRouter(
  CategoryRepository categories,
  MapReportRepository reports,
  LocationGateway location, {
  TileProviderFactory tiles = MapTiles.create,
}) {
  return GoRouter(
    initialLocation: '/mapa',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ProjectShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/mapa',
            builder: (_, _) =>
                CityMapPage(reports: reports, location: location, tiles: tiles),
          ),
          GoRoute(
            path: '/reportes',
            builder: (_, _) =>
                CategoryCatalog(categories: categories.watchCategories()),
          ),
          GoRoute(
            path: '/nuevo',
            builder: (_, _) => const FoundationPage(
              title: 'Crear reporte',
              icon: Icons.add_location_alt_outlined,
              message: 'Necesitarás iniciar sesión con Google y elegir tu nombre público. Integración pendiente en TASK-005 y TASK-006.',
            ),
          ),
          GoRoute(
            path: '/estadisticas',
            builder: (_, _) => const FoundationPage(
              title: 'Estadísticas locales',
              icon: Icons.bar_chart_outlined,
              message: 'Los indicadores se incorporarán en TASK-008. Los datos de este teléfono no representan a toda la ciudad.',
            ),
          ),
          GoRoute(
            path: '/perfil',
            builder: (_, _) => const FoundationPage(
              title: 'Mi perfil',
              icon: Icons.person_outline,
              message: 'Estás explorando como visitante. El acceso con Google y la elección de nombre se incorporarán en TASK-005.',
            ),
          ),
        ],
      ),
    ],
  );
}
