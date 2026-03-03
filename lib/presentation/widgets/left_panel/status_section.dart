import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// STATUS section -- colour-coded state indicator with context-specific message.
///
/// Per spec Section 4.2:
///   Input Mode:  Idle - "Waiting for input"
///   Running:     Active - "X of Y steps complete" + running step names
///   Complete:    Done - "Analysis complete"
///   Error:       Error - Failed step name and error message
class StatusSection extends StatelessWidget {
  const StatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final successColor =
        isDark ? AppColorsDark.success : AppColors.success;
    final errorColor = isDark ? AppColorsDark.error : AppColors.error;
    final warningColor =
        isDark ? AppColorsDark.warning : AppColors.warning;

    // Determine state
    String stateLabel;
    Color stateColor;
    String statusMessage;

    if (provider.isRunning) {
      stateLabel = 'Running';
      stateColor = isDark ? AppColorsDark.primary : AppColors.primary;
      statusMessage = '${provider.completedSteps} of ${provider.totalSteps} steps complete';
    } else if (provider.isLoading) {
      stateLabel = 'Processing';
      stateColor = isDark ? AppColorsDark.primary : AppColors.primary;
      statusMessage = '';
    } else if (provider.contentMode == ContentMode.display) {
      final run = provider.selectedRun;
      final result = provider.currentResult;
      if (run?.status == 'error') {
        stateLabel = 'Error';
        stateColor = errorColor;
        statusMessage = result?.failedStep != null
            ? 'Failed: ${result!.failedStep}'
            : 'Analysis failed';
      } else if (run?.status == 'stopped') {
        stateLabel = 'Stopped';
        stateColor = warningColor;
        statusMessage = 'Analysis was stopped by user';
      } else {
        stateLabel = 'Complete';
        stateColor = successColor;
        statusMessage = '';
      }
    } else {
      stateLabel = 'Waiting';
      stateColor = textSecondary;
      statusMessage = '';
    }

    final labelColor =
        isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project name
        if (provider.projectName.isNotEmpty)
          Text(
            provider.projectName,
            style: AppTextStyles.label.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        // Team
        if (provider.selectedTeam.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Team: ${provider.selectedTeam}',
            style: AppTextStyles.bodySmall.copyWith(color: labelColor),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // State indicator dot + label
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: stateColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              stateLabel,
              style: AppTextStyles.label.copyWith(color: textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Progress bar when running, status message otherwise
        if (provider.isRunning)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: provider.completedSteps / provider.totalSteps,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                statusMessage,
                style:
                    AppTextStyles.bodySmall.copyWith(color: textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                provider.currentRunningStep,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColorsDark.primary : AppColors.primary,
                ),
              ),
            ],
          )
        else if (provider.isLoading && provider.currentRunningStep.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.xs),
              Text(
                provider.currentRunningStep,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColorsDark.primary : AppColors.primary,
                ),
              ),
            ],
          )
        else if (statusMessage.isNotEmpty)
          Text(
            statusMessage,
            style: AppTextStyles.bodySmall.copyWith(color: textSecondary),
          ),

        // Show error details if in display mode for an error run
        if (!provider.isRunning &&
            provider.contentMode == ContentMode.display &&
            provider.selectedRun?.status == 'error' &&
            provider.currentResult?.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            provider.currentResult!.errorMessage!,
            style: AppTextStyles.bodySmall.copyWith(color: errorColor),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
