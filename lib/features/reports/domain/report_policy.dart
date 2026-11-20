import '../../auth/domain/app_user.dart';
import '../../../core/validation/input_limits.dart';

enum ReportStatus { reported, inFollowUp, resolved }

enum ProposalStatus { pending, approved, rejected }

enum PublicIdentityMode { publicName, anonymous }

abstract final class ReportPolicy {
  static bool canCreate(AppUser? actor) =>
      actor != null &&
      InputLimits.text(
            actor.publicName,
            min: InputLimits.nameMin,
            max: InputLimits.nameMax,
          ) ==
          null;
  static bool canEdit(AppUser? actor, String authorUid, ReportStatus status) =>
      canCreate(actor) &&
      (actor!.role == UserRole.admin ||
          (actor.uid == authorUid && status == ReportStatus.reported));
  static bool canManage(AppUser? actor) =>
      canCreate(actor) && actor!.role == UserRole.admin;
  static bool canTransition(
    AppUser? actor,
    ReportStatus from,
    ReportStatus to,
  ) =>
      canManage(actor) &&
      from != to &&
      ((from == ReportStatus.reported && to == ReportStatus.inFollowUp) ||
          (from == ReportStatus.inFollowUp && to == ReportStatus.reported) ||
          (from == ReportStatus.resolved && to == ReportStatus.inFollowUp));

  /// Resolving requires a separately approved evidence proposal.
  static bool canApprove(
    AppUser? actor,
    ReportStatus report,
    ProposalStatus proposal,
  ) =>
      canManage(actor) &&
      report != ReportStatus.resolved &&
      proposal == ProposalStatus.pending;
}
