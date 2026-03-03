import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_line_weights.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/models/cluster_marker.dart';
import '../../../domain/models/event_count.dart';
import '../../../domain/models/fcs_channel.dart';
import '../../../domain/models/workflow_image.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// Display mode content -- scrollable vertical report with four sections.
///
/// Section 1: Cluster Overview (UMAP plot, cluster count)
/// Section 2: Cluster Identity (heatmap, cluster markers table, UMAP by marker)
/// Section 3: Differential Analysis (proportions bar chart, UMAP by condition)
/// Section 4: Quality Control (event counts, channel reference)
///
/// Action buttons (Re-Run/Export/Delete) are in the Header Panel, not here.
class DisplayContent extends StatelessWidget {
  const DisplayContent({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppColorsDark.background : AppColors.background;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final run = provider.selectedRun;
    final result = provider.currentResult;

    if (run == null) {
      return Container(
        color: bgColor,
        child: Center(
          child: Text(
            'No run selected',
            style: AppTextStyles.body.copyWith(color: textSecondary),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Run title
            Text(
              provider.headerHeading,
              style: AppTextStyles.h1.copyWith(color: textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Error banner for error runs
            if (run.status == 'error' && result?.errorMessage != null)
              _ErrorBanner(
                failedStep: result!.failedStep ?? 'Unknown step',
                errorMessage: result.errorMessage!,
                isDark: isDark,
              ),

            // Section 1: Visualizations (real images from workflow)
            _SectionHeading(
              title: 'Visualizations',
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.md),
            if (result != null && result.images.isNotEmpty) ...[
              Text(
                '${result.images.length} image(s) from workflow',
                style: AppTextStyles.bodyLarge.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final img in result.images) ...[
                _MemoryImageCard(
                  imageData: img.data,
                  caption: '${img.filename}  [${img.stepName}]',
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ] else
              Text(
                'No visualizations available for this run.',
                style: AppTextStyles.body.copyWith(color: textSecondary),
              ),

            const SizedBox(height: AppSpacing.xl),

            // Section 2: Cluster Identity (data tables)
            if (result != null && result.clusterMarkers.isNotEmpty) ...[
              _SectionHeading(
                title: 'Cluster Identity',
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Significant Cluster Markers (p < 0.10)',
                style: AppTextStyles.h3.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ClusterMarkersTable(
                markers: result.clusterMarkers,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Section 3: Quality Control
            _SectionHeading(
              title: 'Quality Control',
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.md),
            if (result != null) ...[
              Text(
                'Event Count Summary',
                style: AppTextStyles.h3.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              _EventCountTable(
                eventCounts: result.eventCounts,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Channel Reference',
                style: AppTextStyles.h3.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ChannelReferenceTable(
                channels: result.channelReference,
                isDark: isDark,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
        ),
        ),
      ),
    );
  }
}

// =============================================================================
// Section heading
// =============================================================================
class _SectionHeading extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeading({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.h2.copyWith(color: textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Divider(
          color: borderColor,
          thickness: AppLineWeights.lineStandard,
        ),
      ],
    );
  }
}

// =============================================================================
// Error banner
// =============================================================================
class _ErrorBanner extends StatelessWidget {
  final String failedStep;
  final String errorMessage;
  final bool isDark;

  const _ErrorBanner({
    required this.failedStep,
    required this.errorMessage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = isDark ? AppColorsDark.error : AppColors.error;
    final errorBg = isDark
        ? AppColorsDark.error.withValues(alpha: 0.15)
        : AppColors.errorLight;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: errorBg,
        border: Border.all(color: errorColor, width: AppLineWeights.lineStandard),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: errorColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed: $failedStep',
                  style: AppTextStyles.label.copyWith(color: errorColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  errorMessage,
                  style: AppTextStyles.bodySmall.copyWith(color: errorColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Memory image card (real images from Tercen workflow output)
// =============================================================================
class _MemoryImageCard extends StatelessWidget {
  final Uint8List imageData;
  final String caption;
  final bool isDark;

  const _MemoryImageCard({
    required this.imageData,
    required this.caption,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final captionColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: borderColor,
              width: AppLineWeights.lineStandard,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            imageData,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 300,
                color: Colors.white,
                child: Center(
                  child: Text(
                    'Could not decode image\n$caption',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: captionColor),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          caption,
          style: AppTextStyles.bodySmall.copyWith(color: captionColor),
        ),
      ],
    );
  }
}

// =============================================================================
// Cluster markers table
// =============================================================================
class _ClusterMarkersTable extends StatelessWidget {
  final List<ClusterMarker> markers;
  final bool isDark;

  const _ClusterMarkersTable({
    required this.markers,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final headerBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.surfaceElevated;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: AppLineWeights.lineSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(headerBg),
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        horizontalMargin: AppSpacing.md,
        columnSpacing: AppSpacing.lg,
        columns: [
          DataColumn(
            label: Text('Cluster',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
          ),
          DataColumn(
            label: Text('Marker',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
          ),
          DataColumn(
            label: Text('Score',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
            numeric: true,
          ),
          DataColumn(
            label: Text('p-value',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
            numeric: true,
          ),
        ],
        rows: markers.map((m) {
          return DataRow(cells: [
            DataCell(Text(m.cluster,
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text(m.marker,
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text(m.enrichmentScore.toStringAsFixed(2),
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text(m.pValue.toStringAsFixed(3),
                style: AppTextStyles.body.copyWith(color: textPrimary))),
          ]);
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Event count table
// =============================================================================
class _EventCountTable extends StatelessWidget {
  final List<EventCount> eventCounts;
  final bool isDark;

  const _EventCountTable({
    required this.eventCounts,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final headerBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.surfaceElevated;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: AppLineWeights.lineSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(headerBg),
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        horizontalMargin: AppSpacing.md,
        columnSpacing: AppSpacing.lg,
        columns: [
          DataColumn(
            label: Text('File',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
          ),
          DataColumn(
            label: Text('Raw Events',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
            numeric: true,
          ),
          DataColumn(
            label: Text('Post-Filter',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
            numeric: true,
          ),
        ],
        rows: eventCounts.map((ec) {
          return DataRow(cells: [
            DataCell(Text(ec.filename,
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text('${ec.rawEvents}',
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text('${ec.postFilterEvents}',
                style: AppTextStyles.body.copyWith(color: textPrimary))),
          ]);
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Channel reference table
// =============================================================================
class _ChannelReferenceTable extends StatelessWidget {
  final List<FcsChannel> channels;
  final bool isDark;

  const _ChannelReferenceTable({
    required this.channels,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final headerBg =
        isDark ? AppColorsDark.surfaceElevated : AppColors.surfaceElevated;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: AppLineWeights.lineSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(headerBg),
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        horizontalMargin: AppSpacing.md,
        columnSpacing: AppSpacing.lg,
        columns: [
          DataColumn(
            label: Text('Channel Name',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
          ),
          DataColumn(
            label: Text('Description',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
          ),
          DataColumn(
            label: Text('Type',
                style: AppTextStyles.label.copyWith(color: textSecondary)),
          ),
        ],
        rows: channels.map((ch) {
          return DataRow(cells: [
            DataCell(Text(ch.name,
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text(ch.description,
                style: AppTextStyles.body.copyWith(color: textPrimary))),
            DataCell(Text(ch.isQc ? 'QC' : 'Analysis',
                style: AppTextStyles.body.copyWith(color: textSecondary))),
          ]);
        }).toList(),
      ),
    );
  }
}
