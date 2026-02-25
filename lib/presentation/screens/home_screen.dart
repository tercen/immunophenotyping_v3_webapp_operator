import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/left_panel/left_panel.dart';
import '../widgets/left_panel/actions_section.dart';
import '../widgets/left_panel/status_section.dart';
import '../widgets/left_panel/current_run_section.dart';
import '../widgets/left_panel/history_section.dart';
import '../widgets/left_panel/info_section.dart';
import '../widgets/content_panel/content_panel.dart';

/// Home screen: assembles the Type 3 three-panel layout for
/// Flow Immunophenotyping - PhenoGraph.
///
/// The Status Panel sections (left) and Content Panel (right) are app-specific.
/// Header Panel callbacks are wired here to connect provider actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load data on startup (pre-populates run history in mock)
    Future.microtask(() {
      context.read<AppStateProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppStateProvider>();

    return AppShell(
      appTitle: 'Flow Immunophenotyping',
      appIcon: Icons.biotech,
      sections: const [
        // Status Panel sections -- 5 sections per spec Section 4.2
        PanelSection(
          icon: Icons.play_circle_outline,
          label: 'ACTIONS',
          content: ActionsSection(),
        ),
        PanelSection(
          icon: Icons.monitor_heart,
          label: 'STATUS',
          content: StatusSection(),
        ),
        PanelSection(
          icon: Icons.settings_applications,
          label: 'CURRENT RUN',
          content: CurrentRunSection(),
        ),
        PanelSection(
          icon: Icons.history,
          label: 'HISTORY',
          content: HistorySection(),
        ),
        PanelSection(
          icon: Icons.info_outline,
          label: 'INFO',
          content: InfoSection(),
        ),
      ],
      content: const ContentPanel(),
      // Header Panel callbacks
      onPrimaryAction: () {
        // Input mode: advance to next stage, or start run at stage 4.
        // advanceStage() handles the logic: stages 0-3 -> next stage,
        // stage 4 -> startRun() which transitions to Display mode.
        provider.advanceStage();
      },
      onReRun: () {
        final runId = provider.selectedRunId;
        if (runId != null) {
          provider.initiateReRun(runId);
        }
      },
      onExport: () {
        // Export is a no-op in mock mode per spec
      },
      onDelete: () {
        final runId = provider.selectedRunId;
        if (runId != null) {
          _confirmDelete(context, provider, runId);
        }
      },
    );
  }

  void _confirmDelete(BuildContext context, AppStateProvider provider, String runId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete run?'),
        content: const Text(
          'This will permanently delete this run and its results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deleteRun(runId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
