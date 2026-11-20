import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/audit/audit_dao.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_session.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/validation/input_limits.dart';
import '../../auth/domain/app_user.dart';
import '../domain/report_policy.dart';
import '../domain/report_repository.dart';
import 'report_dao.dart';

class SqliteReportRepository implements ReportRepository {
  SqliteReportRepository(
    this.db,
    this.session,
    this.photos, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       dao = ReportDao(db),
       audit = AuditDao(db);
  final AppDatabase db;
  final LocalSession session;
  final PhotoStorage photos;
  final DateTime Function() clock;
  final ReportDao dao;
  final AuditDao audit;

  @override
  Stream<List<ReportSummary>> watchReports() =>
      db.watchQuery({'reports'}, dao.list);

  @override
  Future<ReportDetails?> getReport(String id) => db.transaction(() async {
    final row = await dao.find(id);
    return row?.publicDetails(await dao.images(id));
  });

  Future<void> _validate(
    ReportDraft draft, {
    String? historicalCategory,
  }) async {
    if (InputLimits.text(
              draft.title,
              min: InputLimits.titleMin,
              max: InputLimits.titleMax,
            ) !=
            null ||
        InputLimits.text(
              draft.description,
              min: InputLimits.descriptionMin,
              max: InputLimits.descriptionMax,
            ) !=
            null ||
        !InputLimits.validCoordinates(draft.latitude, draft.longitude) ||
        (draft.addressLabel?.runes.length ?? 0) > 200) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'Revisa título, descripción y ubicación.',
      );
    }
    final category = await db
        .customSelect(
          'SELECT is_active FROM categories WHERE id=?',
          variables: [Variable.withString(draft.categoryId)],
        )
        .getSingleOrNull();
    if (category == null ||
        (category.read<int>('is_active') != 1 &&
            historicalCategory != draft.categoryId)) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'Elige una categoría habilitada.',
      );
    }
    if (draft.photos.isEmpty ||
        draft.photos.length > InputLimits.maxPhotos ||
        draft.photos.map((photo) => photo.relativePath).toSet().length !=
            draft.photos.length) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'Adjunta entre 1 y 5 fotografías distintas.',
      );
    }
    for (final photo in draft.photos) {
      final path = photo.relativePath;
      if (path.isEmpty ||
          path.startsWith('/') ||
          path.contains('\\') ||
          path.contains(':') ||
          path
              .split('/')
              .any((part) => part.isEmpty || part == '.' || part == '..') ||
          photo.bytes < 1 ||
          photo.bytes > InputLimits.maxPhotoBytes ||
          !InputLimits.photoMimeTypes.contains(photo.mimeType)) {
        throw const RepositoryException(
          RepositoryError.invalidInput,
          'Fotografía no válida.',
        );
      }
      if (!await photos.exists(path)) throw const PhotoStorageException();
    }
  }

  void _requireReason(String reason) {
    if (InputLimits.text(
          reason,
          min: InputLimits.noteMin,
          max: InputLimits.noteMax,
        ) !=
        null) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'El motivo debe tener entre 10 y 1.000 caracteres.',
      );
    }
  }

  Future<void> _insertImages(String id, ReportDraft draft, DateTime at) async {
    for (final (index, photo) in draft.photos.indexed) {
      await db.customStatement(
        '''INSERT INTO report_images(id,report_id,local_relative_path,mime_type,byte_size,sort_order,created_at)
        VALUES(?,?,?,?,?,?,?)''',
        [
          const Uuid().v4(),
          id,
          photo.relativePath,
          photo.mimeType,
          photo.bytes,
          index,
          at.toIso8601String(),
        ],
      );
    }
  }

  @override
  Future<String> create(ReportDraft draft) => db.transaction(() async {
    final actor = await session.requireCompleteProfile();
    await _validate(draft);
    session.ensureCurrent(actor);
    final id = const Uuid().v4();
    final now = clock().toUtc();
    await db.customStatement(
      '''INSERT INTO reports(id,author_uid,category_id,title,description,latitude,longitude,address_label,
      public_identity_mode,public_name_snapshot,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        id,
        actor.uid,
        draft.categoryId,
        draft.title.trim(),
        draft.description.trim(),
        draft.latitude,
        draft.longitude,
        draft.addressLabel?.trim(),
        draft.identityMode == PublicIdentityMode.anonymous
            ? 'ANONYMOUS'
            : 'PUBLIC_NAME',
        draft.identityMode == PublicIdentityMode.anonymous
            ? null
            : actor.publicName,
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );
    await _insertImages(id, draft, now);
    await _saveRevision(id, actor, now);
    await db.customStatement(
      '''INSERT INTO report_status_history(id,report_id,to_status,actor_uid,note,created_at)
      VALUES(?,?,?,?,?,?)''',
      [
        const Uuid().v4(),
        id,
        'REPORTED',
        actor.uid,
        'Reporte creado',
        now.toIso8601String(),
      ],
    );
    await audit.append(
      actor: actor,
      action: 'REPORT_CREATED',
      entityType: 'report',
      entityId: id,
      at: now,
    );
    db.changed({
      'reports',
      'report_images',
      'report_status_history',
      'audit_events',
    });
    return id;
  });

  @override
  Future<void> update({
    required String reportId,
    required ReportDraft draft,
    required int expectedRevision,
    required String reason,
  }) => db.transaction(() async {
    final actor = await session.requireCompleteProfile();
    final before = await _requireReport(reportId);
    if (!ReportPolicy.canEdit(actor, before.authorUid, before.status)) {
      throw const RepositoryException(
        RepositoryError.forbidden,
        'No tienes permiso para editar este reporte.',
      );
    }
    if (before.revision != expectedRevision) {
      throw const RepositoryException(
        RepositoryError.conflict,
        'El reporte cambió. Vuelve a cargarlo antes de editar.',
      );
    }
    _requireReason(reason);
    await _validate(
      draft,
      historicalCategory: before.row.read<String>('category_id'),
    );
    final now = clock().toUtc();
    // Preserve the original public name unless the author explicitly switches
    // from anonymity to public attribution. An admin never becomes the author.
    var name = before.row.readNullable<String>('public_name_snapshot');
    if (draft.identityMode == PublicIdentityMode.anonymous) {
      name = null;
    } else if (name == null) {
      final author = await db
          .customSelect(
            'SELECT public_name FROM users WHERE id=?',
            variables: [Variable.withString(before.authorUid)],
          )
          .getSingle();
      name = author.readNullable<String>('public_name');
      if (name == null) {
        throw const RepositoryException(
          RepositoryError.invalidInput,
          'El autor todavía no eligió un nombre público.',
        );
      }
    }
    final previousPhotos = await dao.images(reportId);
    final fields = <String>[
      if (before.row.read<String>('title') != draft.title.trim()) 'title',
      if (before.row.read<String>('description') != draft.description.trim())
        'description',
      if (before.row.read<String>('category_id') != draft.categoryId)
        'category_id',
      if (before.row.read<double>('latitude') != draft.latitude ||
          before.row.read<double>('longitude') != draft.longitude)
        'location',
      if (before.row.readNullable<String>('address_label') !=
          draft.addressLabel?.trim())
        'address_label',
      if (before.row.read<String>('public_identity_mode') !=
          (draft.identityMode == PublicIdentityMode.anonymous
              ? 'ANONYMOUS'
              : 'PUBLIC_NAME'))
        'public_identity_mode',
      if (!_samePhotos(previousPhotos, draft.photos)) 'photos',
    ];
    if (fields.isEmpty) return;
    session.ensureCurrent(actor);
    await _saveRevision(reportId, actor, now);
    await db.customStatement(
      '''UPDATE reports SET category_id=?,title=?,description=?,latitude=?,longitude=?,address_label=?,
      public_identity_mode=?,public_name_snapshot=?,updated_at=?,revision=revision+1 WHERE id=?''',
      [
        draft.categoryId,
        draft.title.trim(),
        draft.description.trim(),
        draft.latitude,
        draft.longitude,
        draft.addressLabel?.trim(),
        draft.identityMode == PublicIdentityMode.anonymous
            ? 'ANONYMOUS'
            : 'PUBLIC_NAME',
        name,
        now.toIso8601String(),
        reportId,
      ],
    );
    if (fields.contains('photos')) {
      // Physical files are retained; replacing metadata never deletes evidence.
      await db.customStatement('DELETE FROM report_images WHERE report_id=?', [
        reportId,
      ]);
      await _insertImages(reportId, draft, now);
    }
    await _saveRevision(reportId, actor, now);
    await audit.append(
      actor: actor,
      action: 'REPORT_UPDATED',
      entityType: 'report',
      entityId: reportId,
      at: now,
      changedFields: fields,
      reason: reason.trim(),
      isDemo: before.isDemo,
    );
    db.changed({'reports', 'report_images', 'audit_events'});
  });

  bool _samePhotos(List<StoredPhoto> a, List<StoredPhoto> b) =>
      a.length == b.length &&
      a.indexed.every(
        (entry) =>
            entry.$2.relativePath == b[entry.$1].relativePath &&
            entry.$2.bytes == b[entry.$1].bytes &&
            entry.$2.mimeType == b[entry.$1].mimeType,
      );

  Future<void> _saveRevision(
    String reportId,
    AppUser actor,
    DateTime at,
  ) async {
    final row = await db
        .customSelect(
          'SELECT * FROM reports WHERE id=?',
          variables: [Variable.withString(reportId)],
        )
        .getSingle();
    final images = await db
        .customSelect(
          'SELECT local_relative_path,mime_type,byte_size,sort_order FROM report_images WHERE report_id=? ORDER BY sort_order',
          variables: [Variable.withString(reportId)],
        )
        .get();
    await db.customStatement(
      '''INSERT OR IGNORE INTO report_revisions(report_id,revision,snapshot_json,changed_by_uid,created_at)
      VALUES(?,?,?,?,?)''',
      [
        reportId,
        row.read<int>('revision'),
        jsonEncode({
          'report': row.data,
          'images': images.map((image) => image.data).toList(),
        }),
        actor.uid,
        at.toIso8601String(),
      ],
    );
  }

  Future<LocalReportRow> _requireReport(String id) async {
    final row = await dao.find(id);
    if (row == null) {
      throw const RepositoryException(
        RepositoryError.notFound,
        'El reporte no está disponible.',
      );
    }
    return row;
  }

  @override
  Future<void> softDelete({required String reportId, required String reason}) =>
      db.transaction(() async {
        final actor = await session.requireCompleteProfile();
        final report = await _requireReport(reportId);
        if (actor.uid != report.authorUid && actor.role != UserRole.admin) {
          throw const RepositoryException(
            RepositoryError.forbidden,
            'No tienes permiso para eliminar este reporte.',
          );
        }
        _requireReason(reason);
        final now = clock().toUtc();
        session.ensureCurrent(actor);
        await _saveRevision(reportId, actor, now);
        await db.customStatement(
          '''UPDATE reports SET deleted_at=?,deleted_by_uid=?,deletion_reason=?,updated_at=?,revision=revision+1 WHERE id=?''',
          [
            now.toIso8601String(),
            actor.uid,
            reason.trim(),
            now.toIso8601String(),
            reportId,
          ],
        );
        await _saveRevision(reportId, actor, now);
        await audit.append(
          actor: actor,
          action: 'REPORT_DELETED',
          entityType: 'report',
          entityId: reportId,
          at: now,
          reason: reason.trim(),
          changedFields: ['deleted_at'],
          isDemo: report.isDemo,
        );
        db.changed({'reports', 'audit_events'});
      });
}
