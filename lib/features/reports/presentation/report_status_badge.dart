import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/report_policy.dart';
import 'report_labels.dart';

extension ReportStatusVisual on ReportStatus {
  IconData get icon => switch (this) {
    ReportStatus.reported => Icons.schedule_rounded,
    ReportStatus.inFollowUp => Icons.manage_search_rounded,
    ReportStatus.resolved => Icons.check_circle_rounded,
  };

  ({Color foreground, Color background}) colors(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<CivicStatusColors>() ??
        (theme.brightness == Brightness.dark ? AppTheme.dark : AppTheme.light)
            .extension<CivicStatusColors>()!;
    return switch (this) {
      ReportStatus.reported => (
        foreground: palette.reported,
        background: palette.reportedContainer,
      ),
      ReportStatus.inFollowUp => (
        foreground: palette.followUp,
        background: palette.followUpContainer,
      ),
      ReportStatus.resolved => (
        foreground: palette.resolved,
        background: palette.resolvedContainer,
      ),
    };
  }
}

class ReportStatusBadge extends StatelessWidget {
  const ReportStatusBadge(this.status, {super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = status.colors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 18, color: colors.foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ReportLabels.status(status),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
