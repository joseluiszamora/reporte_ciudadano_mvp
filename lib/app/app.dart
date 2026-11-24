import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/media/local_photo_reader.dart';
import '../features/reports/data/sqlite_report_read_repository.dart';
import '../features/reports/data/demo_report_loader.dart';
import '../features/reports/presentation/report_filter_cubit.dart';

import '../core/database/app_database.dart';
import '../features/categories/data/sqlite_category_repository.dart';
import '../core/location/geolocator_gateway.dart';
import '../core/location/location_gateway.dart';
import '../features/map/data/sqlite_map_report_repository.dart';
import '../features/map/presentation/map_tiles.dart';

import 'router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_settings.dart';
import '../core/database/local_session.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/data/firebase_google_gateway.dart';
import '../features/auth/data/google_auth_repository.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/auth_route_guard.dart';
import '../features/profile/data/sqlite_my_reports_repository.dart';
import '../core/media/photo_storage.dart';
import '../core/media/private_photo_storage.dart';
import '../core/media/photo_selection.dart';
import '../features/reports/data/report_draft_store.dart';
import '../features/reports/data/report_media_references.dart';
import '../features/reports/data/sqlite_report_repository.dart';
import '../features/reports/data/sqlite_resolution_repository.dart';
import '../core/audit/sqlite_audit_repository.dart';
import '../features/statistics/data/sqlite_statistics_repository.dart';
import '../features/statistics/presentation/statistics_filter_cubit.dart';

class CitizenReportsApp extends StatefulWidget {
  const CitizenReportsApp({
    super.key,
    this.database,
    this.location,
    this.tiles = MapTiles.create,
    this.photos,
    this.authRepository,
    this.photoStorage,
    this.photoSelection,
    this.draftStore,
    this.initialThemeMode = ThemeMode.system,
  });
  final AppDatabase? database;
  final LocationGateway? location;
  final TileProviderFactory tiles;
  final LocalPhotoReader? photos;
  final AuthRepository? authRepository;
  final PhotoStorage? photoStorage;
  final PhotoSelection? photoSelection;
  final ReportDraftStore? draftStore;
  final ThemeMode initialThemeMode;
  @override
  State<CitizenReportsApp> createState() => _CitizenReportsAppState();
}

class _CitizenReportsAppState extends State<CitizenReportsApp> {
  late final AppDatabase db;
  late final GoRouter router;
  final filters = ReportFilterCubit();
  final statisticsFilters = StatisticsFilterCubit();
  late final AuthRepository repository;
  late final AuthCubit auth;
  late final AuthRouterRefresh authRefresh;
  late final theme = ThemeSettings(initialMode: widget.initialThemeMode);
  @override
  void initState() {
    super.initState();
    db = widget.database ?? AppDatabase();
    repository =
        widget.authRepository ??
        GoogleAuthRepository(db, FirebaseGoogleGateway());
    auth = AuthCubit(repository);
    authRefresh = AuthRouterRefresh(auth);
    final session = LocalSession(db, () => repository.currentUser?.uid);
    final storage =
        widget.photoStorage ??
        PrivatePhotoStorage(referenced: ReportMediaReferences(db).contains);
    router = createAppRouter(
      SqliteCategoryRepository(db),
      SqliteMapReportRepository(db),
      widget.location ?? GeolocatorGateway(),
      readReports: SqliteReportReadRepository(db),
      filters: filters,
      photos: widget.photos ?? PrivatePhotoReader(),
      auth: auth,
      authRefresh: authRefresh,
      myReports: SqliteMyReportsRepository(db, session),
      loadDemoReports: DemoReportLoader(db).load,
      writeReports: SqliteReportRepository(db, session, storage),
      resolutions: SqliteResolutionRepository(db, session, storage),
      audit: SqliteAuditRepository(db, session),
      statistics: SqliteStatisticsRepository(db),
      statisticsFilters: statisticsFilters,
      storage: storage,
      selection: widget.photoSelection ?? AndroidPhotoSelection(),
      drafts: widget.draftStore ?? PrivateReportDraftStore(),
      tiles: widget.tiles,
      theme: theme,
    );
    unawaited(auth.initialize());
  }

  @override
  void dispose() {
    router.dispose();
    authRefresh.dispose();
    theme.dispose();
    filters.close();
    statisticsFilters.close();
    unawaited(
      auth.close().then((_) async {
        if (widget.authRepository == null) await repository.close();
        if (widget.database == null) await db.close();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: theme,
    builder: (context, _) => MaterialApp.router(
      title: 'Reportes ciudadanos · El Alto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      locale: const Locale('es', 'BO'),
      supportedLocales: const [Locale('es', 'BO')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    ),
  );
}
