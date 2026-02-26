import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/theme_provider.dart';

/// ACTIONS section -- Run/Stop/Reset buttons with state-driven enabled/disabled.
///
/// All buttons use the same OutlinedButton style, differentiated by color:
///   Run = primary (blue/teal), Stop = error (red), Reset = secondary (grey).
class ActionsSection extends StatelessWidget {
  const ActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final isDisplay = provider.contentMode == ContentMode.display;
    final isInput = provider.contentMode == ContentMode.input;

    // Run: enabled in input mode at stage 4 when not already running
    final canRun = isInput && !provider.isRunning && provider.currentStage == 4;
    // Stop: enabled when running
    final canStop = provider.isRunning;
    // Reset: enabled in display mode when not running
    final canReset = !provider.isRunning && isDisplay;

    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final errorColor = isDark ? AppColorsDark.error : AppColors.error;
    final secondaryColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final disabledColor =
        isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionButton(
          icon: Icons.play_arrow,
          label: 'Run',
          color: canRun ? primaryColor : disabledColor,
          borderColor: canRun ? primaryColor : borderColor,
          onPressed: canRun ? () => provider.startRun() : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _actionButton(
          icon: Icons.stop,
          label: 'Stop',
          color: canStop ? errorColor : disabledColor,
          borderColor: canStop ? errorColor : borderColor,
          onPressed: canStop ? () => provider.stopRun() : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _actionButton(
          icon: Icons.refresh,
          label: 'Reset',
          color: canReset ? secondaryColor : disabledColor,
          borderColor: canReset ? secondaryColor : borderColor,
          onPressed: canReset ? () => provider.resetApp() : null,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: AppSpacing.controlHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: AppTextStyles.label.copyWith(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }
}
