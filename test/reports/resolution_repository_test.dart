import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:reporte_ciudadano_mvp/core/errors/repository_exception.dart';
import 'package:reporte_ciudadano_mvp/core/media/photo_storage.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_resolution_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/data/sqlite_report_read_repository.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';

import '../support/local_fixture.dart';
import '../auth/session_permissions_test.dart' show SwitchingPhotoStorage;

Matcher failure(RepositoryError code) =>
    isA<RepositoryException>().having((e) => e.code, 'code', code);
const evidence = StoredPhoto(
  relativePath: 'photos/b.jpg',
  mimeType: 'image/jpeg',
  bytes: 1024,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalFixture f;
  late SqliteResolutionRepository repository;
  late String id;
  Future<void> account(String uid, {bool admin = false}) async {
    f.uid = uid;
    await f.users.recordGoogleSignIn(uid: uid);
    await f.users.completePublicName('Persona $uid');
    if (admin) {
      await f.db.customStatement("UPDATE users SET role='ADMIN' WHERE id=?", [
        uid,
      ]);
    }
  }

  Future<String> propose({String? receipt}) => repository.propose(
    reportId: id,
    note: 'Se reparó el tramo afectado de la avenida.',
    photo: evidence,
    requestId: receipt ?? const Uuid().v4(),
  );
  Future<int> count(String table) async =>
      (await f.db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');
  setUp(() async {
    f = LocalFixture();
    await f.initialize();
    id = await f.reports.create(f.draft());
    repository = SqliteResolutionRepository(
      f.db,
      f.session,
      f.photos,
      clock: () => f.now,
    );
  });
  tearDown(() => f.db.close());

  test('proposal requires evidence and complete profile, preserves report state and hides proposer identity publicly', () async {
    final proposal = await propose();
    final view = await repository.load(id);
    expect(view.canPropose, isFalse);
    expect(view.proposals.single.id, proposal);
    expect(view.report.status, ReportStatus.reported);
    expect(view.report.resolvedAt, isNull);
    expect(await count('report_status_history'), 1);
    final public = (await SqliteReportReadRepository(f.db)
        .watchDetail(id)
        .first)!;
    expect(
      jsonEncode(
        public.activity.map((e) => {'text': e.text, 'note': e.note}).toList(),
      ),
      isNot(contains('owner')),
    );
    f.uid = null;
    await expectLater(
      propose(),
      throwsA(failure(RepositoryError.unauthenticated)),
    );
    f.uid = 'incomplete';
    await f.users.recordGoogleSignIn(uid: 'incomplete');
    await expectLater(propose(), throwsA(failure(RepositoryError.forbidden)));
  });

  test('receipt is idempotent, one pending per user, other citizens can add evidence and only see their own management proposals', () async {
    final receipt = const Uuid().v4();
    expect(await propose(receipt: receipt), receipt);
    expect(await propose(receipt: receipt), receipt);
    expect(await count('resolution_proposals'), 1);
    await expectLater(propose(), throwsA(failure(RepositoryError.conflict)));
    await account('other');
    expect((await repository.load(id)).proposals, isEmpty);
    await expectLater(
      propose(receipt: receipt),
      throwsA(failure(RepositoryError.conflict)),
    );
    await propose();
    expect((await repository.load(id)).proposals, hasLength(1));
    await account('admin', admin: true);
    expect((await repository.load(id)).proposals, hasLength(2));
  });

  test('citizen cannot review, transition, reopen or query admin controls through repository', () async {
    final proposal = await propose();
    for (final action in [
      () => repository.approve(
        proposalId: proposal,
        reason: 'Evidencia verificada',
      ),
      () => repository.reject(
        proposalId: proposal,
        reason: 'Evidencia insuficiente',
      ),
      () => repository.transition(
        reportId: id,
        to: ReportStatus.inFollowUp,
        expectedRevision: 0,
        reason: 'Comienza la revisión',
      ),
      () => repository.reopen(
        reportId: id,
        reason: 'Nueva incidencia en la zona',
      ),
    ]) {
      await expectLater(action(), throwsA(failure(RepositoryError.forbidden)));
    }
    expect((await repository.load(id)).isAdmin, isFalse);
    expect((await f.reports.getReport(id))!.status, ReportStatus.reported);
  });

  test('approval atomically resolves, supersedes all other pending proposals and records UTC reviewer/history/audit/revisions', () async {
    final chosen = await propose();
    await account('other');
    final other = await propose();
    await account('admin', admin: true);
    f.now = f.now.add(const Duration(hours: 3));
    await repository.approve(
      proposalId: chosen,
      reason: 'Evidencia verificada en campo',
    );
    final detail = (await f.reports.getReport(id))!;
    expect(detail.status, ReportStatus.resolved);
    expect(detail.resolvedAt, f.now);
    expect(detail.revision, 1);
    final proposals = (await repository.load(id)).proposals;
    expect(
      proposals.singleWhere((p) => p.id == chosen).status,
      ProposalStatus.approved,
    );
    expect(
      proposals.singleWhere((p) => p.id == other).reviewNote,
      'Sustituida por propuesta aprobada',
    );
    final review = await f.db
        .customSelect(
          "SELECT reviewer_uid,is_demo_review FROM resolution_proposals WHERE status='APPROVED'",
        )
        .getSingle();
    expect(review.read<String>('reviewer_uid'), 'admin');
    expect(review.read<int>('is_demo_review'), 0);
    final history = await f.db
        .customSelect(
          "SELECT * FROM report_status_history WHERE to_status='RESOLVED'",
        )
        .getSingle();
    expect(history.read<String>('proposal_id'), chosen);
    expect(history.read<String>('from_status'), 'REPORTED');
    expect(await count('report_revisions'), 2);
    for (final action in [
      'PROPOSAL_APPROVED',
      'PROPOSAL_REJECTED',
      'REPORT_STATUS_CHANGED',
    ]) {
      expect(
        await f.db
            .customSelect("SELECT * FROM audit_events WHERE action='$action'")
            .get(),
        hasLength(1),
      );
    }
    await expectLater(
      repository.approve(proposalId: chosen, reason: 'Evidencia verificada'),
      throwsA(failure(RepositoryError.conflict)),
    );
    await expectLater(
      repository.reject(proposalId: chosen, reason: 'Evidencia insuficiente'),
      throwsA(failure(RepositoryError.conflict)),
    );
  });

  test('audit failure rolls back approved proposal, superseded proposals, report, revisions and history', () async {
    final proposal = await propose();
    await account('other');
    await propose();
    await account('admin', admin: true);
    final before = await count('audit_events');
    await f.db.customStatement(
      "CREATE TRIGGER fail_status_audit BEFORE INSERT ON audit_events WHEN NEW.action='REPORT_STATUS_CHANGED' BEGIN SELECT RAISE(ABORT,'test'); END",
    );
    await expectLater(
      repository.approve(proposalId: proposal, reason: 'Evidencia verificada'),
      throwsA(anything),
    );
    expect(
      (await repository.load(id)).proposals
          .every((p) => p.status == ProposalStatus.pending),
      isTrue,
    );
    expect((await f.reports.getReport(id))!.status, ReportStatus.reported);
    expect(await count('report_status_history'), 1);
    expect(await count('report_revisions'), 1);
    expect(await count('audit_events'), before);
  });

  test('rejection preserves report; author can submit again, reviewed proposal cannot be reused', () async {
    final proposal = await propose();
    await account('admin', admin: true);
    await repository.reject(
      proposalId: proposal,
      reason: 'La imagen no demuestra la reparación',
    );
    expect((await f.reports.getReport(id))!.status, ReportStatus.reported);
    expect(await count('report_status_history'), 1);
    await expectLater(
      repository.reject(
        proposalId: proposal,
        reason: 'Otra revisión de la misma imagen',
      ),
      throwsA(failure(RepositoryError.conflict)),
    );
    f.uid = 'owner';
    await propose();
    expect(await count('resolution_proposals'), 2);
  });

  test('reopening clears last resolution but preserves previous approval; new evidence required for second resolution', () async {
    final first = await propose();
    await account('admin', admin: true);
    f.now = f.now.add(const Duration(hours: 1));
    await repository.approve(
      proposalId: first,
      reason: 'Reparación comprobada',
    );
    await repository.reopen(
      reportId: id,
      reason: 'La reparación presenta nuevas fallas',
    );
    expect((await f.reports.getReport(id))!.resolvedAt, isNull);
    expect((await f.reports.getReport(id))!.status, ReportStatus.inFollowUp);
    await expectLater(
      repository.approve(
        proposalId: first,
        reason: 'Se intenta usar evidencia antigua',
      ),
      throwsA(failure(RepositoryError.conflict)),
    );
    f.uid = 'owner';
    final second = await propose();
    f.uid = 'admin';
    f.now = f.now.add(const Duration(days: 1));
    await repository.approve(
      proposalId: second,
      reason: 'La nueva reparación está comprobada',
    );
    expect((await f.reports.getReport(id))!.resolvedAt, f.now);
    expect(
      await f.db
          .customSelect(
            "SELECT * FROM report_status_history WHERE to_status='RESOLVED'",
          )
          .get(),
      hasLength(2),
    );
  });

  test('valid follow up transitions enforce expected revision and cannot bypass evidence by resolving directly', () async {
    await account('admin', admin: true);
    await repository.transition(
      reportId: id,
      to: ReportStatus.inFollowUp,
      expectedRevision: 0,
      reason: 'Iniciar comprobación en campo',
    );
    await expectLater(
      repository.transition(
        reportId: id,
        to: ReportStatus.reported,
        expectedRevision: 0,
        reason: 'Devolver reporte a revisión',
      ),
      throwsA(failure(RepositoryError.conflict)),
    );
    await expectLater(
      repository.transition(
        reportId: id,
        to: ReportStatus.resolved,
        expectedRevision: 1,
        reason: 'Resolver sin evidencia registrada',
      ),
      throwsA(failure(RepositoryError.conflict)),
    );
    await repository.transition(
      reportId: id,
      to: ReportStatus.reported,
      expectedRevision: 1,
      reason: 'Devolver reporte a revisión',
    );
    expect((await f.reports.getReport(id))!.revision, 2);
    expect(await count('report_status_history'), 3);
  });

  test('deleted reports reject proposals and reviews; evidence and pending proposal remain for audit', () async {
    final proposal = await propose();
    await f.reports.softDelete(reportId: id, reason: 'El reporte es duplicado');
    await account('admin', admin: true);
    for (final action in [
      () => repository.load(id),
      () => propose(),
      () => repository.approve(
        proposalId: proposal,
        reason: 'Evidencia verificada',
      ),
      () => repository.reject(
        proposalId: proposal,
        reason: 'Evidencia insuficiente',
      ),
    ]) {
      await expectLater(action(), throwsA(failure(RepositoryError.notFound)));
    }
    expect(await count('resolution_proposals'), 1);
    expect(f.photos.paths, contains('photos/b.jpg'));
  });

  test('missing evidence, invalid notes and traversal never insert a proposal; approval also requires existing evidence', () async {
    await expectLater(
      repository.propose(
        reportId: id,
        note: 'corta',
        photo: evidence,
        requestId: const Uuid().v4(),
      ),
      throwsA(failure(RepositoryError.invalidInput)),
    );
    await expectLater(
      repository.propose(
        reportId: id,
        note: 'Evidencia de reparación realizada',
        photo: const StoredPhoto(
          relativePath: 'photos/../a.jpg',
          mimeType: 'image/jpeg',
          bytes: 10,
        ),
        requestId: const Uuid().v4(),
      ),
      throwsA(failure(RepositoryError.invalidInput)),
    );
    f.photos.paths.remove('photos/b.jpg');
    await expectLater(propose(), throwsA(isA<PhotoStorageException>()));
    expect(await count('resolution_proposals'), 0);
    f.photos.paths.add('photos/b.jpg');
    final proposal = await propose();
    f.photos.paths.remove('photos/b.jpg');
    await account('admin', admin: true);
    await expectLater(
      repository.approve(proposalId: proposal, reason: 'Evidencia verificada'),
      throwsA(isA<PhotoStorageException>()),
    );
    expect((await f.reports.getReport(id))!.status, ReportStatus.reported);
    await expectLater(
      repository.reject(proposalId: proposal, reason: 'corto'),
      throwsA(failure(RepositoryError.invalidInput)),
    );
  });

  test(
    'account change during evidence verification cancels creation and approval',
    () async {
      final switching = SqliteResolutionRepository(
        f.db,
        f.session,
        SwitchingPhotoStorage(() => f.uid = null),
      );
      await expectLater(
        switching.propose(
          reportId: id,
          note: 'Evidencia de reparación realizada',
          photo: evidence,
          requestId: const Uuid().v4(),
        ),
        throwsA(failure(RepositoryError.unauthenticated)),
      );
      expect(await count('resolution_proposals'), 0);
      f.uid = 'owner';
      final proposal = await propose();
      await account('admin', admin: true);
      await expectLater(
        switching.approve(proposalId: proposal, reason: 'Evidencia verificada'),
        throwsA(failure(RepositoryError.unauthenticated)),
      );
      expect((await f.reports.getReport(id))!.status, ReportStatus.reported);
    },
  );

  test('demo reviews propagate to all mutation audit and status history, without marking real reports demo', () async {
    await f.db.customStatement('UPDATE reports SET is_demo=1 WHERE id=?', [id]);
    final proposal = await propose();
    await account('admin', admin: true);
    await repository.approve(
      proposalId: proposal,
      reason: 'Revisión simulada de evidencia',
    );
    final rows = await f.db
        .customSelect(
          "SELECT is_demo FROM audit_events WHERE action IN ('PROPOSAL_CREATED','PROPOSAL_APPROVED','REPORT_STATUS_CHANGED')",
        )
        .get();
    expect(rows, hasLength(3));
    expect(rows.every((row) => row.read<int>('is_demo') == 1), isTrue);
    expect(
      (await f.db
              .customSelect(
                "SELECT is_demo_action FROM report_status_history WHERE to_status='RESOLVED'",
              )
              .getSingle())
          .read<int>('is_demo_action'),
      1,
    );
  });
}
