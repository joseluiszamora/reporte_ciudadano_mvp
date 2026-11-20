class AuditFilter {
  const AuditFilter({
    this.actorUid,
    this.action,
    this.entityType,
    this.entityId,
    this.isDemo,
    this.from,
    this.to,
  });
  final String? actorUid;
  final String? action;
  final String? entityType;
  final String? entityId;
  final bool? isDemo;
  final DateTime? from;
  final DateTime? to;
  // `from` inclusive, `to` exclusive, instants converted to UTC by repository.
}

abstract interface class AuditRepository {
  /// Private admin-only report. Mutations append events in their own transaction.
  Future<List<Map<String, Object?>>> query(AuditFilter filter);
}
