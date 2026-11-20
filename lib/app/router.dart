import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/project_shell.dart';
import '../features/categories/domain/category_repository.dart';
import '../core/media/local_photo_reader.dart';
import '../features/reports/domain/report_read_repository.dart';
import '../features/reports/presentation/report_filter_cubit.dart';
import '../features/reports/presentation/report_list_page.dart';
import '../features/reports/presentation/report_detail_page.dart';
import '../core/location/location_gateway.dart';
import '../features/map/domain/map_report_repository.dart';
import '../features/map/presentation/city_map_page.dart';
import '../features/map/presentation/map_tiles.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/auth_pages.dart';
import '../features/auth/presentation/auth_route_guard.dart';
import '../features/profile/domain/my_reports_repository.dart';
import '../features/profile/presentation/profile_page.dart';

GoRouter createAppRouter(
  CategoryRepository categories,
  MapReportRepository reports,
  LocationGateway location, {
  required ReportReadRepository readReports,
  required ReportFilterCubit filters,
  required LocalPhotoReader photos,
  required AuthCubit auth,
  required AuthRouterRefresh authRefresh,
  required MyReportsRepository myReports,
  TileProviderFactory tiles = MapTiles.create,
}) {
  return GoRouter(
    initialLocation: '/mapa',
    refreshListenable: authRefresh,
    redirect: (_, state) => authRedirect(auth.state, state.uri),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ProjectShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/mapa',
            builder: (context, _) => CityMapPage(
              reports: reports,
              location: location,
              tiles: tiles,
              filters: filters,
              categories: categories,
              onOpenReport: (id) =>
                  context.push('/reporte/${Uri.encodeComponent(id)}'),
            ),
          ),
          GoRoute(
            path: '/reportes',
            builder: (context, _) => ReportListPage(
              repository: readReports,
              filters: filters,
              categories: categories,
              photos: photos,
              onOpen: (id) =>
                  context.push('/reporte/${Uri.encodeComponent(id)}'),
              onCreate: () => context.go('/nuevo'),
            ),
          ),
          GoRoute(
            path: '/nuevo',
            builder: (_, _) => const FoundationPage(
              title: 'Crear reporte',
              icon: Icons.add_location_alt_outlined,
              message: 'Tu sesión está lista. El formulario para registrar problemas estará disponible en la próxima versión.',
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
            builder: (_, _) => ProfilePage(auth: auth, reports: myReports),
          ),
        ],
      ),
      GoRoute(
        path: '/reporte/:id',
        builder: (_, state) => ReportDetailPage(
          id: state.pathParameters['id']!,
          repository: readReports,
          photos: photos,
          tiles: tiles,
        ),
      ),
      GoRoute(
        path: '/acceso',
        builder: (_, _) => LoginPage(auth: auth),
      ),
      GoRoute(
        path: '/nombre',
        builder: (_, _) => PublicNamePage(auth: auth),
      ),
    ],
  );
}
