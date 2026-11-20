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
import '../domain/resolution_repository.dart';
import 'report_dao.dart';

class SqliteResolutionRepository implements ResolutionRepository {
  SqliteResolutionRepository(
    this.db,
    this.session,
    this.photos, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final LocalSession session;
  final PhotoStorage photos;
  final DateTime Function() clock;
  ReportDao get _dao => ReportDao(db);

  Never _fail(RepositoryError code, String message) =>
      throw RepositoryException(code, message);
  void _requireReason(String value) {
    if (InputLimits.text(
          value,
          min: InputLimits.noteMin,
          max: InputLimits.noteMax,
        ) !=
        null) {
      _fail(
        RepositoryError.invalidInput,
        'La nota o motivo debe tener entre 10 y 1.000 caracteres.',
      );
    }
  }

  Future<AppUser> _requireAdmin() async {
    final actor = await session.requireCompleteProfile();
    if (!ReportPolicy.canManage(actor)) {
      _fail(
        RepositoryError.forbidden,
        'Esta acción requiere permisos de administrador.',
      );
    }
    return actor;
  }

  Future<LocalReportRow> _requireReport(String id) async {
    final row = await _dao.find(id);
    if (row == null) {
      _fail(RepositoryError.notFound, 'El reporte no está disponible.');
    }
    return row;
  }

  @override
  Future<ReportManagement> load(String reportId) => db.transaction(() async {
    final actor = await session.requireCompleteProfile();
    final row = await _requireReport(reportId);
    final images = await _dao.images(reportId);
    final isAdmin = ReportPolicy.canManage(actor);
    final proposals = await db
        .customSelect(
          '''SELECT id,note,evidence_image_path,status,created_at,review_note
      FROM resolution_proposals WHERE report_id=? AND (?=1 OR proposer_uid=?) ORDER BY created_at,id''',
          variables: [
            Variable.withString(reportId),
            Variable.withInt(isAdmin ? 1 : 0),
            Variable.withString(actor.uid),
          ],
        )
        .get();
    final ownPending = await db
        .customSelect(
          "SELECT id FROM resolution_proposals WHERE report_id=? AND proposer_uid=? AND status='PENDING'",
          variables: [
            Variable.withString(reportId),
            Variable.withString(actor.uid),
          ],
        )
        .get();
    session.ensureCurrent(actor);
    return ReportManagement(
      report: row.publicDetails(images),
      draft: ReportDraft(
        categoryId: row.row.read<String>('category_id'),
        title: row.row.read<String>('title'),
        description: row.row.read<String>('description'),
        latitude: row.row.read<double>('latitude'),
        longitude: row.row.read<double>('longitude'),
        addressLabel: row.row.readNullable<String>('address_label'),
        identityMode:
            row.row.read<String>('public_identity_mode') == 'ANONYMOUS'
            ? PublicIdentityMode.anonymous
            : PublicIdentityMode.publicName,
        photos: images,
      ),
      canEdit: ReportPolicy.canEdit(actor, row.authorUid, row.status),
      canDelete: isAdmin || actor.uid == row.authorUid,
      isAdmin: isAdmin,
      canPropose: row.status != ReportStatus.resolved && ownPending.isEmpty,
      proposals: List.unmodifiable(
        proposals.map(
          (p) => ResolutionProposal(
            id: p.read<String>('id'),
            note: p.read<String>('note'),
            photoPath: p.read<String>('evidence_image_path'),
            status: ProposalStatus.values.byName(
              p.read<String>('status').toLowerCase(),
            ),
            createdAt: DateTime.parse(p.read<String>('created_at')),
            reviewNote: p.readNullable<String>('review_note'),
          ),
        ),
      ),
    );
  });

  Future<void> _validatePhoto(StoredPhoto photo) async {
    final path = photo.relativePath;
    if (!path.startsWith('photos/') ||
        path.contains('\\') ||
        path.contains(':') ||
        path.split('/').any((p) => p.isEmpty || p == '.' || p == '..') ||
        photo.bytes < 1 ||
        photo.bytes > InputLimits.maxPhotoBytes ||
        !InputLimits.photoMimeTypes.contains(photo.mimeType)) {
      _fail(RepositoryError.invalidInput, 'Fotografía de evidencia no válida.');
    }
    if (!await photos.exists(path)) throw const PhotoStorageException();
  }

  @override
  Future<String> propose({
    required String reportId,
    required String note,
    required StoredPhoto photo,
    required String requestId,
  }) => db.transaction(() async {
    final actor = await session.requireCompleteProfile();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(requestId)) {
      _fail(
        RepositoryError.invalidInput,
        'Identificador de propuesta no válido.',
      );
    }
    final row = await _requireReport(reportId);
    final existing = await db
        .customSelect(
          'SELECT proposer_uid,report_id FROM resolution_proposals WHERE id=?',
          variables: [Variable.withString(requestId)],
        )
        .getSingleOrNull();
    session.ensureCurrent(actor);
    if (existing != null) {
      if (existing.read<String>('proposer_uid') != actor.uid ||
          existing.read<String>('report_id') != reportId) {
        _fail(RepositoryError.conflict, 'La propuesta ya no está disponible.');
      }
      return requestId;
    }
    if (row.status == ReportStatus.resolved) {
      _fail(RepositoryError.conflict, 'El reporte ya está solucionado.');
    }
    final pending = await db
        .customSelect(
          "SELECT id FROM resolution_proposals WHERE report_id=? AND proposer_uid=? AND status='PENDING'",
          variables: [
            Variable.withString(reportId),
            Variable.withString(actor.uid),
          ],
        )
        .get();
    if (pending.isNotEmpty) {
      _fail(
        RepositoryError.conflict,
        'Ya tienes una propuesta pendiente para este reporte.',
      );
    }
    _requireReason(note);
    await _validatePhoto(photo);
    session.ensureCurrent(actor);
    final now = clock().toUtc();
    await db.customStatement(
      '''INSERT INTO resolution_proposals(id,report_id,proposer_uid,note,evidence_image_path,created_at)
      VALUES(?,?,?,?,?,?)''',
      [
        requestId,
        reportId,
        actor.uid,
        note.trim(),
        photo.relativePath,
        now.toIso8601String(),
      ],
    );
    await AuditDao(db).append(
      actor: actor,
      action: 'PROPOSAL_CREATED',
      entityType: 'proposal',
      entityId: requestId,
      at: now,
      isDemo: row.isDemo,
    );
    db.changed({'resolution_proposals', 'audit_events'});
    session.ensureCurrent(actor);
    return requestId;
  });

  @override
  Future<void> transition({
    required String reportId,
    required ReportStatus to,
    required int expectedRevision,
    required String reason,
  }) => db.transaction(() async {
    final actor = await _requireAdmin();
    final before = await _requireReport(reportId);
    if (before.revision != expectedRevision) {
      _fail(RepositoryError.conflict, 'El reporte cambió. Vuelve a cargarlo.');
    }
    if (!ReportPolicy.canTransition(actor, before.status, to)) {
      _fail(
        RepositoryError.conflict,
        'Cambio de estado no permitido. Para solucionar se debe aprobar una propuesta.',
      );
    }
    _requireReason(reason);
    session.ensureCurrent(actor);
    await _changeStatus(before, actor, to, reason, clock().toUtc());
    db.changed({
      'reports',
      'report_status_history',
      'report_revisions',
      'audit_events',
    });
    session.ensureCurrent(actor);
  });

  @override
  Future<void> reopen({required String reportId, required String reason}) =>
      db.transaction(() async {
        final actor = await _requireAdmin();
        final before = await _requireReport(reportId);
        if (before.status != ReportStatus.resolved) {
          _fail(
            RepositoryError.conflict,
            'Solo se puede reabrir un reporte solucionado.',
          );
        }
        _requireReason(reason);
        session.ensureCurrent(actor);
        await _changeStatus(
          before,
          actor,
          ReportStatus.inFollowUp,
          reason,
          clock().toUtc(),
        );
        db.changed({
          'reports',
          'report_status_history',
          'report_revisions',
          'audit_events',
        });
        session.ensureCurrent(actor);
      });

  Future<void> _changeStatus(
    LocalReportRow before,
    AppUser actor,
    ReportStatus to,
    String note,
    DateTime now, {
    String? proposalId,
  }) async {
    final id = before.row.read<String>('id');
    await _dao.saveRevision(id, actor, now);
    await db.customStatement(
      '''UPDATE reports SET status=?,resolved_at=?,updated_at=?,revision=revision+1 WHERE id=?''',
      [
        statusToSql(to),
        to == ReportStatus.resolved ? now.toIso8601String() : null,
        now.toIso8601String(),
        id,
      ],
    );
    await db.customStatement(
      '''INSERT INTO report_status_history(id,report_id,from_status,to_status,actor_uid,proposal_id,note,created_at,is_demo_action)
      VALUES(?,?,?,?,?,?,?,?,?)''',
      [
        const Uuid().v4(),
        id,
        statusToSql(before.status),
        statusToSql(to),
        actor.uid,
        proposalId,
        note.trim(),
        now.toIso8601String(),
        before.isDemo ? 1 : 0,
      ],
    );
    await _dao.saveRevision(id, actor, now);
    await AuditDao(db).append(
      actor: actor,
      action: 'REPORT_STATUS_CHANGED',
      entityType: 'report',
      entityId: id,
      at: now,
      changedFields: ['status', 'resolved_at'],
      reason: note.trim(),
      isDemo: before.isDemo,
    );
  }

  Future<QueryRow> _pendingProposal(String id) async {
    final p = await db
        .customSelect(
          'SELECT * FROM resolution_proposals WHERE id=?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (p == null) {
      _fail(RepositoryError.notFound, 'La propuesta no está disponible.');
    }
    if (p.read<String>('status') != 'PENDING') {
      _fail(RepositoryError.conflict, 'Esta propuesta ya fue revisada.');
    }
    return p;
  }

  Future<void> _review(
    QueryRow p,
    LocalReportRow report,
    AppUser actor,
    bool approve,
    String note,
    DateTime now,
  ) async {
    final id = p.read<String>('id');
    await db.customStatement(
      '''UPDATE resolution_proposals SET status=?,reviewed_at=?,reviewer_uid=?,review_note=?,is_demo_review=? WHERE id=?''',
      [
        approve ? 'APPROVED' : 'REJECTED',
        now.toIso8601String(),
        actor.uid,
        note.trim(),
        report.isDemo ? 1 : 0,
        id,
      ],
    );
    await AuditDao(db).append(
      actor: actor,
      action: approve ? 'PROPOSAL_APPROVED' : 'PROPOSAL_REJECTED',
      entityType: 'proposal',
      entityId: id,
      at: now,
      reason: note.trim(),
      changedFields: ['status', 'reviewed_at'],
      isDemo: report.isDemo,
    );
  }

  @override
  Future<void> approve({required String proposalId, required String reason}) =>
      db.transaction(() async {
        final actor = await _requireAdmin();
        final p = await _pendingProposal(proposalId);
        final before = await _requireReport(p.read<String>('report_id'));
        if (!ReportPolicy.canApprove(
          actor,
          before.status,
          ProposalStatus.pending,
        )) {
          _fail(RepositoryError.conflict, 'El reporte ya está solucionado.');
        }
        _requireReason(reason);
        if (!await photos.exists(p.read<String>('evidence_image_path'))) {
          throw const PhotoStorageException();
        }
        session.ensureCurrent(actor);
        final now = clock().toUtc();
        final other = await db
            .customSelect(
              "SELECT * FROM resolution_proposals WHERE report_id=? AND status='PENDING' AND id<>?",
              variables: [
                Variable.withString(p.read<String>('report_id')),
                Variable.withString(proposalId),
              ],
            )
            .get();
        session.ensureCurrent(actor);
        await _review(p, before, actor, true, reason, now);
        for (final item in other) {
          await _review(
            item,
            before,
            actor,
            false,
            'Sustituida por propuesta aprobada',
            now,
          );
        }
        await _changeStatus(
          before,
          actor,
          ReportStatus.resolved,
          reason,
          now,
          proposalId: proposalId,
        );
        db.changed({
          'reports',
          'resolution_proposals',
          'report_status_history',
          'report_revisions',
          'audit_events',
        });
        session.ensureCurrent(actor);
      });

  @override
  Future<void> reject({required String proposalId, required String reason}) =>
      db.transaction(() async {
        final actor = await _requireAdmin();
        final p = await _pendingProposal(proposalId);
        final before = await _requireReport(p.read<String>('report_id'));
        _requireReason(reason);
        session.ensureCurrent(actor);
        await _review(p, before, actor, false, reason, clock().toUtc());
        db.changed({'resolution_proposals', 'audit_events'});
        session.ensureCurrent(actor);
      });
}
