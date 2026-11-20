import 'package:drift/drift.dart';

import '../domain/report_read_repository.dart';
import 'report_dao.dart';

ReportListItem reportListItem(QueryRow row) => ReportListItem(
  id: row.read<String>('id'),
  title: row.read<String>('title'),
  category: row.read<String>('category'),
  status: statusFromSql(row.read<String>('status')),
  createdAt: DateTime.parse(row.read<String>('created_at')),
  isDemo: row.read<int>('is_demo') == 1,
  latitude: row.read<double>('latitude'),
  longitude: row.read<double>('longitude'),
  address: row.readNullable<String>('address_label'),
  photoPath: row.readNullable<String>('photo_path'),
  resolvedAt: row.readNullable<String>('resolved_at') == null
      ? null
      : DateTime.parse(row.read<String>('resolved_at')),
);
