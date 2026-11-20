class AuditFilter {
  const AuditFilter({this.actorUid, this.action, this.from, this.to});
  final String? actorUid;
  final String? action;
  final DateTime? from;
  final DateTime? to;
}

abstract interface class AuditRepository {
  /// Private admin-only report. Mutations append events in their own transaction.
  Future<List<Map<String, Object?>>> query(AuditFilter filter);
}
