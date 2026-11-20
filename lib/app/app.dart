import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/media/local_photo_reader.dart';
import '../features/reports/data/sqlite_report_read_repository.dart';
import '../features/reports/presentation/report_filter_cubit.dart';

import '../core/database/app_database.dart';
import '../features/categories/data/sqlite_category_repository.dart';
import '../core/location/geolocator_gateway.dart';
import '../core/location/location_gateway.dart';
import '../features/map/data/sqlite_map_report_repository.dart';
import '../features/map/presentation/map_tiles.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../core/database/local_session.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/data/firebase_google_gateway.dart';
import '../features/auth/data/google_auth_repository.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/auth_route_guard.dart';
import '../features/profile/data/sqlite_my_reports_repository.dart';

class CitizenReportsApp extends StatefulWidget {
  const CitizenReportsApp({
    super.key,
    this.database,
    this.location,
    this.tiles = MapTiles.create,
    this.photos,
    this.authRepository,
  });
  final AppDatabase? database;
  final LocationGateway? location;
  final TileProviderFactory tiles;
  final LocalPhotoReader? photos;
  final AuthRepository? authRepository;
  @override
  State<CitizenReportsApp> createState() => _CitizenReportsAppState();
}

class _CitizenReportsAppState extends State<CitizenReportsApp> {
  late final AppDatabase db;
  late final GoRouter router;
  final filters = ReportFilterCubit();
  late final AuthRepository repository;
  late final AuthCubit auth;
  late final AuthRouterRefresh authRefresh;
  @override
  void initState() {
    super.initState();
    db = widget.database ?? AppDatabase();
    repository =
        widget.authRepository ??
        GoogleAuthRepository(db, FirebaseGoogleGateway());
    auth = AuthCubit(repository);
    authRefresh = AuthRouterRefresh(auth);
    router = createAppRouter(
      SqliteCategoryRepository(db),
      SqliteMapReportRepository(db),
      widget.location ?? GeolocatorGateway(),
      readReports: SqliteReportReadRepository(db),
      filters: filters,
      photos: widget.photos ?? PrivatePhotoReader(),
      auth: auth,
      authRefresh: authRefresh,
      myReports: SqliteMyReportsRepository(
        db,
        LocalSession(db, () => repository.currentUser?.uid),
      ),
      tiles: widget.tiles,
    );
    unawaited(auth.initialize());
  }

  @override
  void dispose() {
    router.dispose();
    authRefresh.dispose();
    filters.close();
    unawaited(
      auth.close().then((_) async {
        if (widget.authRepository == null) await repository.close();
        if (widget.database == null) await db.close();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Reportes ciudadanos · El Alto',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('es', 'BO'),
    supportedLocales: const [Locale('es', 'BO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}
