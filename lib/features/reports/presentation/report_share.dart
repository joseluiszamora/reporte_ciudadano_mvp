import 'package:flutter/services.dart';

import '../domain/report_read_repository.dart';
import 'report_labels.dart';

class ReportShare {
  static const _channel = MethodChannel('bo.elalto.reports/share');

  static String summary(ReportView view) {
    final report = view.details;
    return [
      if (report.isDemo) 'Reporte de demostración',
      report.title,
      'Categoría: ${view.category}',
      'Estado: ${ReportLabels.status(report.status)}',
      'Autor: ${report.publicAuthor}',
      'Creado: ${ReportLabels.date(report.createdAt)}',
      'Ubicación: ${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
      '',
      report.description,
      '',
      'Reporte local de El Alto',
    ].join('\n');
  }

  static Future<void> send(String summary) =>
      _channel.invokeMethod<void>('shareText', {'text': summary});
}
