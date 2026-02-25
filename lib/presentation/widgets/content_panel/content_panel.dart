import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import 'input_content.dart';
import 'display_content.dart';

/// Content Panel — switches between Input and Display mode based on provider state.
///
/// Replace InputContent and DisplayContent with your app's specific screens.
class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final contentMode = context.watch<AppStateProvider>().contentMode;

    return switch (contentMode) {
      ContentMode.input => const InputContent(),
      ContentMode.display => const DisplayContent(),
    };
  }
}
