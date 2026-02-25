import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/app_state_provider.dart';
import '../providers/theme_provider.dart';

/// Header Panel — 48px fixed strip at top of the right column.
///
/// Two zones: left-aligned context label, right-aligned action buttons.
/// Content changes by mode (Input / Display / Running).
///
/// DO NOT MODIFY this widget directly. Apps configure it via AppStateProvider:
/// - setHeaderConfig(heading, actionLabel) for Input mode
/// - selectHistoryEntry() for Display mode heading
/// - startRun() / stopRun() for Running state dimming
class HeaderPanel extends StatelessWidget {
  /// Callback when the primary action button is pressed in Input mode.
  final VoidCallback? onPrimaryAction;

  /// Callback when Re-Run is pressed in Display mode.
  final VoidCallback? onReRun;

  /// Callback when Export is pressed in Display mode.
  final VoidCallback? onExport;

  /// Callback when Delete is pressed in Display mode.
  final VoidCallback? onDelete;

  const HeaderPanel({
    super.key,
    this.onPrimaryAction,
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
    final textPrimary = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    return Container(
      height: AppSpacing.topBarHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // Left zone: context label
          Expanded(
            child: Text(
              provider.headerHeading,
              style: AppTextStyles.h3.copyWith(color: textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Right zone: action buttons
          ..._buildActions(context, provider, isDark),
        ],
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    AppStateProvider provider,
    bool isDark,
  ) {
    if (provider.contentMode == ContentMode.input) {
      return [
        FilledButton(
          onPressed: onPrimaryAction,
          child: Text(provider.headerActionLabel),
        ),
      ];
    }

    // Display mode
    final outlineColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    return [
      OutlinedButton.icon(
        onPressed: onReRun,
        icon: Icon(Icons.replay, size: 16, color: outlineColor),
        label: Text('Re-Run', style: TextStyle(color: outlineColor)),
      ),
      const SizedBox(width: AppSpacing.sm),
      OutlinedButton.icon(
        onPressed: onExport,
        icon: Icon(Icons.download, size: 16, color: outlineColor),
        label: Text('Export', style: TextStyle(color: outlineColor)),
      ),
      const SizedBox(width: AppSpacing.sm),
      OutlinedButton.icon(
        onPressed: onDelete,
        icon: Icon(Icons.delete_outline, size: 16, color: isDark ? AppColorsDark.error : AppColors.error),
        label: Text('Delete', style: TextStyle(color: isDark ? AppColorsDark.error : AppColors.error)),
      ),
    ];
  }
}
