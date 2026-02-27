import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/app_state_provider.dart';
import '../providers/theme_provider.dart';

/// Header Panel — 48px fixed strip at top of the right column.
///
/// Two zones: left-aligned context label, right-aligned action buttons.
/// Button bar changes dynamically based on app state:
///
///   State                  | Pos 1   | Pos 2  | Pos 3 | Pos 4
///   -----------------------|---------|--------|-------|---------------
///   Create Project         |         |        |       | Create Project
///   Upload FCS Files       |         |        |       | Continue
///   Upload Sample Ann.     |         |        | Reset | Continue
///   Select Channels        |         |        | Reset | Continue
///   Analysis Settings      |         |        | Reset | Run
///   Running                |         |        |       | Stop
///   Display                | Delete  | Export | Reset | Re-Run
class HeaderPanel extends StatelessWidget {
  static const double _primaryButtonWidth = 140.0;

  final VoidCallback? onExit;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onStop;
  final VoidCallback? onReset;
  final VoidCallback? onReRun;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  const HeaderPanel({
    super.key,
    this.onExit,
    this.onPrimaryAction,
    this.onStop,
    this.onReset,
    this.onReRun,
    this.onExport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    return Container(
      height: AppSpacing.topBarHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      // Left padding aligns action buttons with the content margin below.
      // Right padding mirrors the standard horizontal margin.
      padding: const EdgeInsets.only(
        left: AppSpacing.md + 32 + AppSpacing.sm,
        right: AppSpacing.md,
      ),
      child: Row(
        children: [
          // Action buttons — left-aligned to content margin
          ..._buildActions(provider, isDark),
          // Spacer fills all available width (responsive to screen size)
          const Spacer(),
          // Divider + Exit — pinned to right edge
          Container(width: 1, height: 20, color: borderColor),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onExit,
            icon: Icon(Icons.close, size: 18, color: isDark ? AppColorsDark.textSecondary : AppColors.textSecondary),
            tooltip: 'Exit',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(AppStateProvider provider, bool isDark) {
    final outlineColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final errorColor = isDark ? AppColorsDark.error : AppColors.error;
    final buttons = <Widget>[];

    if (provider.isRunning) {
      // Running: [_, _, _, Stop]
      buttons.add(SizedBox(
        width: _primaryButtonWidth,
        child: FilledButton.icon(
          onPressed: onStop,
          style: FilledButton.styleFrom(backgroundColor: errorColor),
          icon: const Icon(Icons.stop, size: 16),
          label: const Text('Stop'),
        ),
      ));
      return buttons;
    }

    if (provider.contentMode == ContentMode.display) {
      // Display: [Delete, Export, Reset, Re-Run]
      buttons.add(_outlinedButton(
        icon: Icons.delete_outline,
        label: 'Delete',
        color: errorColor,
        onPressed: onDelete,
      ));
      buttons.add(const SizedBox(width: AppSpacing.sm));
      buttons.add(_outlinedButton(
        icon: Icons.download,
        label: 'Export',
        color: outlineColor,
        onPressed: onExport,
      ));
      buttons.add(const SizedBox(width: AppSpacing.sm));
      buttons.add(_outlinedButton(
        icon: Icons.refresh,
        label: 'Reset',
        color: outlineColor,
        onPressed: onReset,
      ));
      buttons.add(const SizedBox(width: AppSpacing.sm));
      buttons.add(SizedBox(
        width: _primaryButtonWidth,
        child: FilledButton(
          onPressed: onReRun,
          child: const Text('Re-Run'),
        ),
      ));
      return buttons;
    }

    // Input mode: buttons depend on stage
    final stage = provider.currentStage;

    // Pos 3: Reset (visible from stage 2+)
    if (stage >= 2) {
      buttons.add(_outlinedButton(
        icon: Icons.refresh,
        label: 'Reset',
        color: outlineColor,
        onPressed: onReset,
      ));
      buttons.add(const SizedBox(width: AppSpacing.sm));
    }

    // Pos 4: primary action
    final isRun = provider.headerActionLabel == 'Run';
    buttons.add(SizedBox(
      width: _primaryButtonWidth,
      child: isRun
          ? FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Run'),
            )
          : FilledButton(
              onPressed: onPrimaryAction,
              child: Text(provider.headerActionLabel),
            ),
    ));

    return buttons;
  }

  Widget _outlinedButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}
