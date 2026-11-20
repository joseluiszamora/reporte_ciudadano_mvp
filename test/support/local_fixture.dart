import 'package:drift/native.dart';
import 'package:reporte_ciudadano_mvp/core/database/app_database.dart';
import 'package:reporte_ciudadano_mvp/core/database/local_session.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/auth/data/local_user_store.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_repository.dart';

class TestPhotoStorage implements PhotoStorage {
  final paths = <String>{'photos/a.jpg', 'photos/b.jpg'};
  @override
  Future<bool> exists(String relativePath) async =>
      paths.contains(relativePath);
  @override
  Future<StoredPhoto> import(String sourcePath) => throw UnimplementedError();
  @override
  Future<void> remove(String relativePath) async => paths.remove(relativePath);
}

class LocalFixture {
  LocalFixture({AppDatabase? database})
    : db = database ?? AppDatabase.forTesting(NativeDatabase.memory());
  final AppDatabase db;
  String? uid = 'owner';
  final photos = TestPhotoStorage();
  DateTime now = DateTime.utc(2026, 11, 19, 12);
  late final session = LocalSession(db, () => uid);
  late final users = LocalUserStore(db, session, clock: () => now);
  late final reports = SqliteReportRepository(
    db,
    session,
    photos,
    clock: () => now,
  );

  Future<void> initialize() async {
    await users.recordGoogleSignIn(uid: 'owner', email: 'private@example.test');
    await users.completePublicName('Vecina');
  }

  ReportDraft draft({
    String title = 'Bache en avenida',
    String category = 'baches',
    PublicIdentityMode identity = PublicIdentityMode.anonymous,
    List<StoredPhoto>? images,
  }) => ReportDraft(
    categoryId: category,
    title: title,
    description: 'Un bache afecta el paso de vehículos.',
    latitude: -16.5,
    longitude: -68.15,
    identityMode: identity,
    photos:
        images ??
        [
          const StoredPhoto(
            relativePath: 'photos/a.jpg',
            mimeType: 'image/jpeg',
            bytes: 1024,
          ),
        ],
  );
}
