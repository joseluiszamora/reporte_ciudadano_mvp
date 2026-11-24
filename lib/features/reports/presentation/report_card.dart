import 'package:flutter/material.dart';

import '../../../core/design_system/civic_feedback.dart';
import '../../../core/media/local_photo_reader.dart';
import '../domain/report_read_repository.dart';
import 'report_labels.dart';
import 'report_photo.dart';
import 'report_status_badge.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    required this.photos,
    required this.onOpen,
  });

  final ReportListItem report;
  final LocalPhotoReader photos;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final photo = report.photoPath == null
        ? null
        : AspectRatio(
            aspectRatio: 4 / 3,
            child: ReportPhoto(
              path: report.photoPath,
              reader: photos,
              expandable: false,
            ),
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.isDemo) ...[
                    const DemoBanner(),
                    const SizedBox(height: 12),
                  ],
                  Text(report.category, style: metadata),
                  const SizedBox(height: 4),
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ReportStatusBadge(report.status),
                      Text(
                        ReportLabels.elapsed(
                          report.createdAt,
                          report.resolvedAt,
                          DateTime.now(),
                        ),
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.address ??
                        '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                    style: metadata,
                  ),
                  Text(ReportLabels.date(report.createdAt), style: metadata),
                ],
              ),
            );
            if (photo != null && constraints.maxWidth >= 480) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 192, child: photo),
                  Expanded(child: content),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [?photo, content],
            );
          },
        ),
      ),
    );
  }
}
