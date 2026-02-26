import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// CURRENT RUN section -- compact key: value pairs, one per line.
/// Uses m-dash separators to group related values on a single line.
class CurrentRunSection extends StatelessWidget {
  const CurrentRunSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final labelColor =
        isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final valueColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    // In display mode, show the selected run's settings
    List<(String, String)> lines;
    if (provider.contentMode == ContentMode.display &&
        provider.selectedRun != null) {
      lines = _linesFromRun(provider.selectedRun!);
    } else {
      lines = _linesFromInput(provider);
    }

    if (lines.isEmpty) {
      return Text(
        'No active run',
        style: AppTextStyles.bodySmall.copyWith(color: labelColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: AppTextStyles.bodySmall.copyWith(color: valueColor),
              children: [
                TextSpan(
                  text: '${line.$1}: ',
                  style: AppTextStyles.bodySmall.copyWith(color: labelColor),
                ),
                TextSpan(text: line.$2),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Build compact lines from current input state.
  List<(String, String)> _linesFromInput(AppStateProvider p) {
    final lines = <(String, String)>[];

    if (p.fcsUploaded) {
      lines.add(('FCS', '${p.fcsFilename} (${p.fcsFileCount} files, ${p.fcsChannelCount} ch)'));
    }
    if (p.annotationUploaded) {
      lines.add(('Annotation', '${p.annotationFilename} (${p.annotationSampleCount} samples)'));
    }
    if (p.currentStage >= 3) {
      lines.add(('Channels', '${p.selectedChannelCount} of ${p.allChannels.length} \u2014 ${p.maxEventsPerFile} evt/file'));
    }
    if (p.currentStage >= 4 || p.contentMode == ContentMode.display) {
      lines.add(('Params', 'k=${p.phenographK} \u2014 n=${p.umapNNeighbors} \u2014 dist=${p.umapMinDist} \u2014 seed=${p.randomSeed}'));
      if (p.runName.isNotEmpty) {
        lines.add(('Run', p.runName));
      }
    }

    return lines;
  }

  /// Build compact lines from a history run entry.
  List<(String, String)> _linesFromRun(RunEntry run) {
    final s = run.settings;
    final lines = <(String, String)>[];

    final fcsName = s['fcsFilename'] as String? ?? '';
    if (fcsName.isNotEmpty) {
      lines.add(('FCS', '$fcsName (${s['fcsFileCount'] ?? 0} files, ${s['totalChannels'] ?? 0} ch)'));
    }

    final annName = s['annotationFilename'] as String? ?? '';
    if (annName.isNotEmpty) {
      lines.add(('Annotation', '$annName (${s['sampleCount'] ?? 0} samples)'));
    }

    lines.add(('Channels', '${s['selectedChannelCount'] ?? 0} of ${s['totalChannels'] ?? 0} \u2014 ${s['maxEventsPerFile'] ?? 0} evt/file'));
    lines.add(('Params', 'k=${s['phenographK'] ?? 30} \u2014 n=${s['umapNNeighbors'] ?? 15} \u2014 dist=${s['umapMinDist'] ?? 0.5} \u2014 seed=${s['randomSeed'] ?? 42}'));

    return lines;
  }
}
