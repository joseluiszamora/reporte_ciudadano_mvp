import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';

/// SQL migrations with typed DAOs at the data boundary.
class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(driftDatabase(name: 'citizen_reports'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await transaction(() async {
        await _applyAsset('assets/database/schema_v1.sql');
        await _applyAsset('assets/database/schema_v2.sql');
      });
    },
    onUpgrade: (_, from, to) async {
      if (from == 1 && to == 2) {
        await transaction(() => _applyAsset('assets/database/schema_v2.sql'));
      } else {
        throw StateError('Migración no compatible: $from → $to');
      }
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _applyAsset(String path) async {
    final sql = await rootBundle.loadString(path);
    for (final statement in sql.split(';')) {
      if (statement.trim().isNotEmpty) await customStatement(statement);
    }
  }

  /// Register before the first read, so a concurrent commit cannot be missed.
  /// Drift buffers notifications until commit and discards them on rollback.
  Stream<T> watchQuery<T>(Set<String> tables, Future<T> Function() load) {
    late StreamController<void> refresh;
    StreamSubscription<Set<TableUpdate>>? subscription;
    refresh = StreamController<void>(
      onListen: () {
        subscription = tableUpdates().listen((updates) {
          if (updates.any((update) => tables.contains(update.table))) {
            refresh.add(null);
          }
        }, onDone: () => refresh.close());
        refresh.add(null);
      },
      onCancel: () => subscription?.cancel(),
    );
    return refresh.stream.asyncMap((_) => load());
  }

  void changed(Set<String> tables) =>
      notifyUpdates({for (final table in tables) TableUpdate(table)});
}
