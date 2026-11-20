abstract interface class ResolutionRepository {
  /// Update proposal, report, status history and audit in one transaction.
  /// Other pending proposals are rejected as superseded in that transaction.
  Future<void> approve({required String proposalId, required String reason});
  Future<void> reject({required String proposalId, required String reason});
  Future<void> reopen({required String reportId, required String reason});
}
