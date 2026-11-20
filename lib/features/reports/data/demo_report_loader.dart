import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Inserts fictional samples only when explicitly requested from the profile.
class DemoReportLoader {
  DemoReportLoader(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;
  static const _source = 'local:demo-report-source';

  Future<bool> load() => db.transaction(() async {
    final source = await db
        .customSelect(
          'SELECT 1 FROM users WHERE id=?',
          variables: [Variable.withString(_source)],
        )
        .getSingleOrNull();
    // The source row is the receipt. Keep it even if samples are soft-deleted.
    if (source != null) return false;

    final now = _clock().toUtc();
    await db.customStatement(
      'INSERT INTO users(id,created_at,last_sign_in_at) VALUES(?,?,?)',
      [_source, now.toIso8601String(), now.toIso8601String()],
    );
    const examples = [
      (
        category: 'baches',
        title: 'Bache en una vía de ejemplo',
        description:
            'Caso ficticio para explorar un reporte recién registrado.',
        latitude: -16.500,
        longitude: -68.151,
        status: 'REPORTED',
      ),
      (
        category: 'alumbrado',
        title: 'Luminaria en seguimiento',
        description:
            'Caso ficticio para mostrar cómo se registra el seguimiento.',
        latitude: -16.505,
        longitude: -68.155,
        status: 'IN_FOLLOW_UP',
      ),
      (
        category: 'basura',
        title: 'Residuos retirados en un ejemplo',
        description: 'Caso ficticio de solución para consultar el historial y los tiempos.',
        latitude: -16.495,
        longitude: -68.145,
        status: 'RESOLVED',
      ),
    ];
    for (final (index, example) in examples.indexed) {
      final id = 'd1000000-0000-4000-8000-00000000000${index + 1}';
      final created = now.subtract(Duration(days: index + 1));
      final changed = example.status == 'REPORTED'
          ? created
          : created.add(const Duration(hours: 12));
      await db.customStatement(
        '''INSERT INTO reports(id,author_uid,category_id,title,description,
        latitude,longitude,status,public_identity_mode,is_demo,created_at,updated_at,resolved_at)
        VALUES(?,?,?,?,?,?,?,?,'ANONYMOUS',1,?,?,?)''',
        [
          id,
          _source,
          example.category,
          example.title,
          example.description,
          example.latitude,
          example.longitude,
          example.status,
          created.toIso8601String(),
          changed.toIso8601String(),
          example.status == 'RESOLVED' ? changed.toIso8601String() : null,
        ],
      );
      await _history(
        id,
        index + 1,
        '1',
        null,
        'REPORTED',
        'Ejemplo ficticio cargado',
        created,
      );
      if (example.status != 'REPORTED') {
        await _history(
          id,
          index + 1,
          '2',
          'REPORTED',
          example.status,
          'Cambio de estado simulado',
          changed,
        );
      }
    }
    db.changed({'reports', 'report_status_history'});
    return true;
  });

  Future<void> _history(
    String reportId,
    int number,
    String step,
    String? from,
    String to,
    String note,
    DateTime at,
  ) => db.customStatement(
    '''INSERT INTO report_status_history(id,report_id,from_status,to_status,actor_uid,note,created_at,is_demo_action)
        VALUES(?,?,?,?,?,?,?,1)''',
    [
      'd2000000-0000-4000-8000-0000000000$number$step',
      reportId,
      from,
      to,
      _source,
      note,
      at.toIso8601String(),
    ],
  );
}
