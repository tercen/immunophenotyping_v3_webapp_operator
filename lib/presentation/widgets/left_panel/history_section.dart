import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// HISTORY section -- list of past runs with traffic-light status dots.
///
/// Per spec Section 4.2:
///   Green dot = complete, Orange dot = stopped, Red dot = error.
///   Most recent first. Click loads results in Display mode.
class HistorySection extends StatelessWidget {
  const HistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final selectedBg =
        isDark ? AppColorsDark.primarySurface : AppColors.primarySurface;

    final history = provider.runHistory;

    if (history.isEmpty) {
      return Text(
        'No runs yet',
        style: AppTextStyles.bodySmall.copyWith(color: textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: history.map((run) {
        final isSelected = run.id == provider.selectedRunId;
        return InkWell(
          onTap: () => provider.selectHistoryEntry(run.id),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                // Traffic-light status dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(run.status, isDark),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Run name and timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.name,
                        style: AppTextStyles.label.copyWith(
                          color: textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatTimestamp(run.timestamp),
                        style: AppTextStyles.labelSmall
                            .copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(String status, bool isDark) {
    return switch (status) {
      'complete' => isDark ? AppColorsDark.success : AppColors.success,
      'error' => isDark ? AppColorsDark.error : AppColors.error,
      'stopped' => isDark ? AppColorsDark.warning : AppColors.warning,
      _ => isDark ? AppColorsDark.textMuted : AppColors.textMuted,
    };
  }

  String _formatTimestamp(DateTime ts) {
    return '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  }
}
