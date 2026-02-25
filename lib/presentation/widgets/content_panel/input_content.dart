import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../domain/models/fcs_channel.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// Input mode content -- switches between 5 input stages.
///
/// Stage 0: Project Setup (standalone only)
/// Stage 1: Upload FCS Files
/// Stage 2: Upload Sample Annotation
/// Stage 3: Channel Selection & Downsampling
/// Stage 4: Analysis Settings & Run
class InputContent extends StatelessWidget {
  const InputContent({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppColorsDark.background : AppColors.background;

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: switch (provider.currentStage) {
          0 => _Stage0ProjectSetup(isDark: isDark),
          1 => _Stage1UploadFcs(isDark: isDark),
          2 => _Stage2UploadAnnotation(isDark: isDark),
          3 => _Stage3ChannelSelection(isDark: isDark),
          4 => _Stage4AnalysisSettings(isDark: isDark),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

// =============================================================================
// Stage 0: Project Setup
// =============================================================================
class _Stage0ProjectSetup extends StatelessWidget {
  final bool isDark;
  const _Stage0ProjectSetup({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a team and name your project.',
          style: AppTextStyles.body.copyWith(color: textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        // TEAM section
        Text(
          'TEAM',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('Team',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          value: provider.selectedTeam,
          decoration: const InputDecoration(isDense: true),
          items: provider.availableTeams
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (value) {
            if (value != null) provider.setSelectedTeam(value);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        // PROJECT section
        Text(
          'PROJECT',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('Project name',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          initialValue: provider.projectName,
          decoration: const InputDecoration(
            hintText: 'Enter project name...',
            isDense: true,
          ),
          onChanged: (value) => provider.setProjectName(value),
        ),
      ],
    );
  }
}

// =============================================================================
// Stage 1: Upload FCS Files
// =============================================================================
class _Stage1UploadFcs extends StatelessWidget {
  final bool isDark;
  const _Stage1UploadFcs({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final successColor = isDark ? AppColorsDark.success : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FCS DATA section
        Text(
          'FCS DATA',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        // Drop zone
        if (!provider.fcsUploaded)
          _DropZone(
            isDark: isDark,
            icon: Icons.cloud_upload_outlined,
            label: 'Drag & drop FCS zip file or browse',
            onTap: () => provider.simulateFcsUpload(),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColorsDark.surface : AppColors.surface,
              border: Border.all(color: successColor),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: successColor, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        provider.fcsFilename ?? '',
                        style: AppTextStyles.label
                            .copyWith(color: textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: labelColor),
                      onPressed: () => provider.clearFcsUpload(),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${provider.fcsFileCount} FCS files  |  '
                  '${provider.fcsChannelCount} channels  |  '
                  '${_formatFileSize(provider.fcsFileSize)}',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: labelColor),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// =============================================================================
// Stage 2: Upload Sample Annotation
// =============================================================================
class _Stage2UploadAnnotation extends StatelessWidget {
  final bool isDark;
  const _Stage2UploadAnnotation({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final successColor = isDark ? AppColorsDark.success : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ANNOTATION section
        Text(
          'ANNOTATION',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        // Drop zone
        if (!provider.annotationUploaded)
          _DropZone(
            isDark: isDark,
            icon: Icons.cloud_upload_outlined,
            label: 'Drag & drop annotation CSV or browse',
            onTap: () => provider.simulateAnnotationUpload(),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColorsDark.surface : AppColors.surface,
              border: Border.all(color: successColor),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: successColor, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        provider.annotationFilename ?? '',
                        style: AppTextStyles.label
                            .copyWith(color: textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: labelColor),
                      onPressed: () => provider.clearAnnotationUpload(),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${provider.annotationSampleCount} samples  |  '
                  '${provider.annotationConditions.length} conditions  |  '
                  'Cross-check: ${provider.annotationCrossCheckPassed ? "passed" : "failed"}',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: labelColor),
                ),
                if (provider.annotationConditions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Conditions: ${provider.annotationConditions.join(", ")}',
                    style:
                        AppTextStyles.bodySmall.copyWith(color: labelColor),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Stage 3: Channel Selection & Downsampling
// =============================================================================
class _Stage3ChannelSelection extends StatelessWidget {
  final bool isDark;
  const _Stage3ChannelSelection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CHANNEL SELECTION section
        Row(
          children: [
            Text(
              'CHANNEL SELECTION',
              style:
                  AppTextStyles.sectionHeader.copyWith(color: labelColor),
            ),
            const Spacer(),
            Text(
              '${provider.selectedChannelCount} of ${provider.allChannels.length} selected',
              style: AppTextStyles.bodySmall.copyWith(color: labelColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        // Select All / Deselect All
        Row(
          children: [
            OutlinedButton(
              onPressed: () => provider.selectAllChannels(),
              child: const Text('Select All'),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => provider.deselectAllChannels(),
              child: const Text('Deselect All'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        // Channel checkbox grid
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: provider.allChannels.map((ch) {
            final isSelected =
                provider.selectedChannels[ch.name] ?? false;
            return SizedBox(
              width: 180,
              child: Tooltip(
                message: ch.name,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) => provider.setChannelSelected(
                            ch.name, val ?? false),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        ch.description,
                        style: AppTextStyles.body.copyWith(
                          color: textPrimary,
                          decoration: ch.isQc
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        // DOWNSAMPLING section
        Text(
          'DOWNSAMPLING',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('Max events per file',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text('400',
                style: AppTextStyles.bodySmall.copyWith(color: labelColor)),
            Expanded(
              child: Slider(
                value: provider.maxEventsPerFile.toDouble(),
                min: 400,
                max: provider.maxPossibleEvents.toDouble(),
                divisions: ((provider.maxPossibleEvents - 400) / 100)
                    .round()
                    .clamp(1, 100),
                label: '${provider.maxEventsPerFile}',
                onChanged: (value) =>
                    provider.setMaxEventsPerFile(value.round()),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                '${provider.maxEventsPerFile}',
                style: AppTextStyles.label.copyWith(color: textPrimary),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Stage 4: Analysis Settings & Run
// =============================================================================
class _Stage4AnalysisSettings extends StatelessWidget {
  final bool isDark;
  const _Stage4AnalysisSettings({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RUN NAME section
        Text(
          'RUN NAME',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('Run name',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          initialValue: provider.runName.isNotEmpty
              ? provider.runName
              : provider.defaultRunName,
          decoration: const InputDecoration(
            hintText: 'Enter run name...',
            isDense: true,
          ),
          onChanged: (value) => provider.setRunName(value),
        ),
        const SizedBox(height: AppSpacing.lg),
        // CLUSTERING section
        Text(
          'CLUSTERING',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('PhenoGraph k',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 120,
          child: TextFormField(
            initialValue: '${provider.phenographK}',
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final k = int.tryParse(value);
              if (k != null && k > 0) provider.setPhenographK(k);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // DIMENSION REDUCTION section
        Text(
          'DIMENSION REDUCTION',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('UMAP n_neighbors',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 120,
          child: TextFormField(
            initialValue: '${provider.umapNNeighbors}',
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final n = int.tryParse(value);
              if (n != null && n > 0) provider.setUmapNNeighbors(n);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('UMAP min_dist',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 120,
          child: TextFormField(
            initialValue: '${provider.umapMinDist}',
            decoration: const InputDecoration(isDense: true),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final d = double.tryParse(value);
              if (d != null && d >= 0.0 && d <= 1.0) {
                provider.setUmapMinDist(d);
              }
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // REPRODUCIBILITY section
        Text(
          'REPRODUCIBILITY',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        Text('Random seed',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 120,
          child: TextFormField(
            initialValue: '${provider.randomSeed}',
            decoration: const InputDecoration(isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final s = int.tryParse(value);
              if (s != null && s > 0) provider.setRandomSeed(s);
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared: Drop Zone widget (simulated file upload)
// =============================================================================
class _DropZone extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DropZone({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final primaryColor =
        isDark ? AppColorsDark.primary : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: AppLineWeights.lineStandard),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          color: isDark ? AppColorsDark.surface : AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: primaryColor),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.body.copyWith(color: labelColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Click to simulate upload',
              style: AppTextStyles.bodySmall.copyWith(color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
