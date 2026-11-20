import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/repository_exception.dart';
import '../domain/statistics_repository.dart';

class SqliteStatisticsRepository implements StatisticsRepository {
  SqliteStatisticsRepository(
    this.db, {
    DateTime Function()? clock,
    Stream<void> Function()? ticks,
  }) : _clock = clock ?? DateTime.now,
       _ticks = ticks ?? _minuteTicks;
  final AppDatabase db;
  final DateTime Function() _clock;
  final Stream<void> Function() _ticks;
  static Stream<void> _minuteTicks() =>
      Stream<void>.periodic(const Duration(minutes: 1), (_) {});

  @override
  Stream<LocalStatistics> watch(StatisticsFilter filter) {
    late StreamController<void> refresh;
    StreamSubscription<Set<TableUpdate>>? updates;
    StreamSubscription<void>? ticks;
    refresh = StreamController<void>(
      onListen: () {
        // Register before reading; asyncMap serializes clock and commit refreshes.
        updates = db.tableUpdates().listen((changes) {
          if (changes.any(
            (change) =>
                change.table == 'reports' || change.table == 'categories',
          )) {
            refresh.add(null);
          }
        }, onDone: () => refresh.close());
        ticks = _ticks().listen((_) {
          if (!refresh.isClosed) refresh.add(null);
        }, onError: refresh.addError);
        refresh.add(null);
      },
      onCancel: () async {
        await updates?.cancel();
        await ticks?.cancel();
      },
    );
    return refresh.stream.asyncMap((_) => _load(filter));
  }

  Future<LocalStatistics> _load(StatisticsFilter filter) async {
    if (filter.from != null &&
        filter.until != null &&
        !filter.from!.isBefore(filter.until!)) {
      throw const RepositoryException(
        RepositoryError.invalidInput,
        'Revisa el intervalo de fechas.',
      );
    }
    final where = <String>['r.deleted_at IS NULL'];
    final args = <Variable>[];
    if (!filter.includeDemo) where.add('r.is_demo=0');
    if (filter.categoryId != null) {
      where.add('r.category_id=?');
      args.add(Variable.withString(filter.categoryId!));
    }
    // One read snapshot, no joins to photos/proposals that could multiply counts.
    // Only fields needed for aggregates; no UIDs, titles, notes or private identity.
    final rows = await db.customSelect(
      '''SELECT r.status,r.created_at,r.resolved_at,r.is_demo,
      c.id AS category_id,c.name AS category_name,c.is_active AS category_active
      FROM reports r JOIN categories c ON c.id=r.category_id
      WHERE ${where.join(' AND ')} ORDER BY c.sort_order,c.name,c.id''',
      variables: args,
    ).get();
    // ISO timestamps can have three or six fractional digits. Compare instants,
    // not strings, to preserve exact boundaries around midnight/microseconds.
    final selected = rows.where((row) {
      final created = DateTime.parse(row.read<String>('created_at'));
      return (filter.from == null || !created.isBefore(filter.from!)) &&
          (filter.until == null || created.isBefore(filter.until!));
    }).toList();
    final now = _clock().toUtc();
    return LocalStatistics(
      local: _group(
        selected.where((row) => row.read<int>('is_demo') == 0),
        now,
      ),
      demo: filter.includeDemo
          ? _group(selected.where((row) => row.read<int>('is_demo') == 1), now)
          : null,
      asOf: now,
    );
  }

  StatisticsGroup _group(Iterable<QueryRow> rows, DateTime now) {
    var total = 0;
    var reported = 0;
    var followUp = 0;
    var resolved = 0;
    var pendingMicros = 0;
    var resolutionMicros = 0;
    var oldestMicros = 0;
    final categoryCounts = <String, int>{};
    final categoryRows = <String, QueryRow>{};
    for (final row in rows) {
      total++;
      final category = row.read<String>('category_id');
      categoryRows[category] = row;
      categoryCounts.update(category, (value) => value + 1, ifAbsent: () => 1);
      final created = DateTime.parse(row.read<String>('created_at'));
      final isResolved = row.read<String>('status') == 'RESOLVED';
      final end = isResolved
          ? DateTime.parse(row.read<String>('resolved_at'))
          : now;
      final rawMicros = end.difference(created).inMicroseconds;
      final micros = rawMicros < 0 ? 0 : rawMicros;
      if (isResolved) {
        resolved++;
        resolutionMicros += micros;
      } else {
        if (row.read<String>('status') == 'REPORTED') {
          reported++;
        } else {
          followUp++;
        }
        pendingMicros += micros;
        if (micros > oldestMicros) oldestMicros = micros;
      }
    }
    final pending = reported + followUp;
    return StatisticsGroup(
      total: total,
      reported: reported,
      inFollowUp: followUp,
      resolved: resolved,
      averagePendingAge: pending == 0
          ? null
          : Duration(microseconds: (pendingMicros / pending).round()),
      oldestPendingAge: pending == 0
          ? null
          : Duration(microseconds: oldestMicros),
      averageResolutionTime: resolved == 0
          ? null
          : Duration(microseconds: (resolutionMicros / resolved).round()),
      categories: [
        for (final entry in categoryCounts.entries)
          CategoryStatistics(
            id: entry.key,
            name: categoryRows[entry.key]!.read<String>('category_name'),
            isActive:
                categoryRows[entry.key]!.read<int>('category_active') == 1,
            total: entry.value,
          ),
      ],
    );
  }
}
