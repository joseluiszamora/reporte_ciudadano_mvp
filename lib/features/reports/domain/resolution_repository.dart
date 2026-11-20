import '../../../core/media/photo_storage.dart';
import 'report_policy.dart';
import 'report_repository.dart';

class ResolutionProposal {
  const ResolutionProposal({
    required this.id,
    required this.note,
    required this.photoPath,
    required this.status,
    required this.createdAt,
    this.reviewNote,
  });
  final String id;
  final String note;
  final String photoPath;
  final ProposalStatus status;
  final DateTime createdAt;
  final String? reviewNote;
}

/// Private, session-bound projection. No author identifiers reach public views.
class ReportManagement {
  const ReportManagement({
    required this.report,
    required this.draft,
    required this.canEdit,
    required this.canDelete,
    required this.isAdmin,
    required this.canPropose,
    required this.proposals,
  });
  final ReportDetails report;
  final ReportDraft draft;
  final bool canEdit;
  final bool canDelete;
  final bool isAdmin;
  final bool canPropose;
  final List<ResolutionProposal> proposals;
}

abstract interface class ResolutionRepository {
  Future<ReportManagement> load(String reportId);
  Future<String> propose({
    required String reportId,
    required String note,
    required StoredPhoto photo,
    required String requestId,
  });
  Future<void> transition({
    required String reportId,
    required ReportStatus to,
    required int expectedRevision,
    required String reason,
  });

  /// Update proposal, report, status history and audit in one transaction.
  /// Other pending proposals are rejected as superseded in that transaction.
  Future<void> approve({required String proposalId, required String reason});
  Future<void> reject({required String proposalId, required String reason});
  Future<void> reopen({required String reportId, required String reason});
}
