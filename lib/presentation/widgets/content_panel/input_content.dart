import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';
import '../upload_zone.dart';

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
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    return Container(
      color: bgColor,
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.md + 32 + AppSpacing.sm,
            right: AppSpacing.md,
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.headerHeading,
                style: AppTextStyles.h1.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              switch (provider.currentStage) {
                0 => _Stage0ProjectSetup(isDark: isDark),
                1 => _Stage1UploadFcs(isDark: isDark),
                2 => _Stage2UploadAnnotation(isDark: isDark),
                3 => _Stage3ChannelSelection(isDark: isDark),
                4 => _Stage4AnalysisSettings(isDark: isDark),
                _ => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Stage 0: Project Setup
// =============================================================================
class _Stage0ProjectSetup extends StatefulWidget {
  final bool isDark;
  const _Stage0ProjectSetup({required this.isDark});

  @override
  State<_Stage0ProjectSetup> createState() => _Stage0ProjectSetupState();
}

class _Stage0ProjectSetupState extends State<_Stage0ProjectSetup> {
  late final TextEditingController _projectNameController;
  bool _userHasEdited = false;
  AppStateProvider? _provider;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppStateProvider>();
    if (_provider != provider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _provider!.addListener(_onProviderChanged);
      // Seed controller with whatever the provider currently has.
      if (_projectNameController.text.isEmpty) {
        _projectNameController.text = provider.projectName;
      }
    }
  }

  void _onProviderChanged() {
    if (!_userHasEdited && _provider != null) {
      final newName = _provider!.projectName;
      if (_projectNameController.text != newName) {
        _projectNameController.text = newName;
        _projectNameController.selection = TextSelection.fromPosition(
          TextPosition(offset: newName.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _projectNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final labelColor = widget.isDark
        ? AppColorsDark.textSecondary
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SELECT TEAM section
        Text(
          'SELECT TEAM',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        SizedBox(
          width: 320,
          child: DropdownButtonFormField<String>(
            value: provider.availableTeams.contains(provider.selectedTeam)
                ? provider.selectedTeam
                : null,
            decoration: const InputDecoration(isDense: true),
            hint: provider.isLoading
                ? const Text('Loading teams...')
                : const Text('Select a team'),
            items: provider.availableTeams
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (value) {
              if (value != null) provider.setSelectedTeam(value);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // PROJECT NAME section
        Text(
          'PROJECT NAME',
          style: AppTextStyles.sectionHeader.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        SizedBox(
          width: 480,
          child: TextFormField(
            controller: _projectNameController,
            decoration: const InputDecoration(
              hintText: 'Enter project name...',
              isDense: true,
            ),
            onChanged: (value) {
              _userHasEdited = true;
              provider.setProjectName(value);
            },
          ),
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
    final provider = context.read<AppStateProvider>();
    final labelColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FCS files must be in a .zip folder.',
          style: AppTextStyles.bodySmall.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        UploadZone(
          isDark: isDark,
          label: 'Drag & Drop or Click to Browse',
          onFilesChanged: (files) => provider.updateFcsUploadFromFiles(files),
        ),
      ],
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CSV file required.',
          style: AppTextStyles.bodySmall.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppSpacing.controlSpacing),
        UploadZone(
          isDark: isDark,
          label: 'Drag & Drop or Click to Browse',
          onFilesChanged: (files) =>
              provider.updateAnnotationUploadFromFiles(files),
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
        Text('Events per file',
            style: AppTextStyles.label.copyWith(color: labelColor)),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('${provider.minEventsPerFile}',
                    style: AppTextStyles.bodySmall.copyWith(color: labelColor),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                child: RangeSlider(
                  values: RangeValues(
                    provider.minEventsPerFile.toDouble(),
                    provider.maxEventsPerFile.toDouble(),
                  ),
                  min: 1,
                  max: provider.maxPossibleEvents.toDouble(),
                  divisions: (provider.maxPossibleEvents - 1)
                      .clamp(1, 1000),
                  labels: RangeLabels(
                    '${provider.minEventsPerFile}',
                    '${provider.maxEventsPerFile}',
                  ),
                  onChanged: (values) => provider.setEventsPerFileRange(
                    values.start.round(),
                    values.end.round(),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${provider.maxEventsPerFile}',
                  style: AppTextStyles.bodySmall.copyWith(color: labelColor),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
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
        SizedBox(
          width: 480,
          child: TextFormField(
            initialValue: provider.runName.isNotEmpty
                ? provider.runName
                : provider.defaultRunName,
            decoration: const InputDecoration(
              hintText: 'Enter run name...',
              isDense: true,
            ),
            onChanged: (value) => provider.setRunName(value),
          ),
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

