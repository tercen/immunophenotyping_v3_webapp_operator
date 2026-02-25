import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// ACTIONS section -- Run/Stop/Reset buttons with state-driven enabled/disabled.
///
/// Button states per spec Section 4.2:
///   Input Mode:  Run=Disabled, Stop=Disabled, Reset=Disabled
///   Running:     Run=Disabled, Stop=Enabled,  Reset=Disabled
///   Stopped:     Run=Enabled,  Stop=Disabled, Reset=Enabled
///   Display:     Run=Disabled, Stop=Disabled, Reset=Enabled
class ActionsSection extends StatelessWidget {
  const ActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final isDisplay = provider.contentMode == ContentMode.display;

    // Run: disabled in mock (no running simulation)
    const canRun = false;
    // Stop: enabled when running
    final canStop = provider.isRunning;
    // Reset: enabled in display mode or when not running
    final canReset = !provider.isRunning && isDisplay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppSpacing.controlHeight,
          child: FilledButton.icon(
            onPressed: canRun ? () => provider.startRun() : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Run'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSpacing.controlHeight,
          child: OutlinedButton.icon(
            onPressed: canStop ? () => provider.stopRun() : null,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSpacing.controlHeight,
          child: TextButton.icon(
            onPressed: canReset ? () => provider.resetApp() : null,
            icon: Icon(
              Icons.refresh,
              size: 18,
              color: canReset
                  ? (isDark
                      ? AppColorsDark.textSecondary
                      : AppColors.textSecondary)
                  : null,
            ),
            label: Text(
              'Reset',
              style: TextStyle(
                color: canReset
                    ? (isDark
                        ? AppColorsDark.textSecondary
                        : AppColors.textSecondary)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
