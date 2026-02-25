import 'package:flutter/material.dart';

/// Running state overlay — blocks interaction and dims the wrapped content.
///
/// When [isRunning] is true:
/// - AbsorbPointer blocks all touch events on Header + Content panels
/// - Content is visually dimmed via reduced opacity
/// - A .gif animation plays centred over the dimmed content
///
/// DO NOT MODIFY this widget. It is part of the skeleton infrastructure.
/// Triggered by AppStateProvider.isRunning.
class RunningOverlay extends StatelessWidget {
  final bool isRunning;
  final Widget child;

  const RunningOverlay({
    super.key,
    required this.isRunning,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRunning) return child;

    return Stack(
      children: [
        // Dimmed content underneath — maintains widget state
        AbsorbPointer(
          absorbing: true,
          child: Opacity(
            opacity: 0.3,
            child: child,
          ),
        ),
        // Centred running animation
        const Positioned.fill(
          child: Center(
            child: _RunningAnimation(),
          ),
        ),
      ],
    );
  }
}

class _RunningAnimation extends StatelessWidget {
  const _RunningAnimation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/running.gif',
          width: 120,
          height: 120,
        ),
        const SizedBox(height: 16),
        Text(
          'Processing...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
