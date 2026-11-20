import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../core/media/photo_storage.dart';
import '../core/media/photo_selection.dart';
import '../features/reports/data/report_draft_store.dart';
import '../features/reports/domain/report_repository.dart';
import '../features/reports/presentation/new_report_page.dart';
import '../features/reports/presentation/report_management_page.dart';
import '../features/reports/domain/resolution_repository.dart';
import '../core/audit/audit_repository.dart';
import '../core/audit/audit_page.dart';
import '../features/statistics/domain/statistics_repository.dart';
import '../features/statistics/presentation/statistics_filter_cubit.dart';
import '../features/statistics/presentation/statistics_page.dart';

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
  required ReportRepository writeReports,
  required ResolutionRepository resolutions,
  required AuditRepository audit,
  required StatisticsRepository statistics,
  required StatisticsFilterCubit statisticsFilters,
  required PhotoStorage storage,
  required PhotoSelection selection,
  required ReportDraftStore drafts,
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
            builder: (context, _) => BlocBuilder<AuthCubit, AuthState>(
              bloc: auth,
              builder: (context, session) {
                if (session.user == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return NewReportPage(
                  key: ValueKey(session.user!.uid),
                  auth: auth,
                  categories: categories,
                  reports: writeReports,
                  storage: storage,
                  selection: selection,
                  drafts: drafts,
                  reader: photos,
                  location: location,
                  tiles: tiles,
                  onSaved: (id) =>
                      context.go('/reporte/${Uri.encodeComponent(id)}'),
                );
              },
            ),
          ),
          GoRoute(
            path: '/estadisticas',
            builder: (context, _) => StatisticsPage(
              repository: statistics,
              categories: categories,
              filters: statisticsFilters,
              onCreate: () => context.go('/nuevo'),
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
        builder: (context, state) => ReportDetailPage(
          id: state.pathParameters['id']!,
          repository: readReports,
          photos: photos,
          tiles: tiles,
          onManage: () => context.push(
            '/gestionar/${Uri.encodeComponent(state.pathParameters['id']!)}',
          ),
        ),
      ),
      GoRoute(
        path: '/gestionar/:id',
        builder: (_, state) => ReportManagementPage(
          id: state.pathParameters['id']!,
          auth: auth,
          resolutions: resolutions,
          reports: writeReports,
          storage: storage,
          selection: selection,
          drafts: drafts,
          reader: photos,
          categories: categories,
          location: location,
          tiles: tiles,
        ),
      ),
      GoRoute(
        path: '/acciones',
        builder: (_, _) => AuditPage(auth: auth, repository: audit),
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
