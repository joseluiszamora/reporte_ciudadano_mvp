import '../domain/report_policy.dart';

abstract final class ReportLabels {
  static String status(ReportStatus status) => switch (status) {
    ReportStatus.reported => 'Reportado',
    ReportStatus.inFollowUp => 'En seguimiento',
    ReportStatus.resolved => 'Solucionado',
  };
  static String date(DateTime value, {bool time = true}) {
    final local = value.toLocal();
    String pad(int number) => number.toString().padLeft(2, '0');
    final day = '${pad(local.day)}/${pad(local.month)}/${local.year}';
    return time ? '$day ${pad(local.hour)}:${pad(local.minute)}' : day;
  }

  static String elapsed(DateTime created, DateTime? resolved, DateTime now) {
    final raw = (resolved ?? now).difference(created);
    final duration = raw.isNegative ? Duration.zero : raw;
    final value = duration.inDays > 0
        ? '${duration.inDays} ${duration.inDays == 1 ? 'día' : 'días'} ${duration.inHours % 24} h'
        : duration.inHours > 0
        ? '${duration.inHours} h'
        : '${duration.inMinutes} min';
    return '${resolved == null ? 'Tiempo pendiente' : 'Resuelto en'}: $value';
  }
}
