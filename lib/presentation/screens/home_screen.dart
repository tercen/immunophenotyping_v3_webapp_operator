import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../providers/app_state_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/left_panel/left_panel.dart';
import '../widgets/left_panel/status_section.dart';
import '../widgets/left_panel/current_run_section.dart';
import '../widgets/left_panel/history_section.dart';
import '../widgets/left_panel/info_section.dart';
import '../widgets/content_panel/content_panel.dart';
import '../../di/service_locator.dart';

/// Home screen: assembles the Type 3 three-panel layout for
/// Flow Immunophenotyping - PhenoGraph.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
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
      onExit: () => _handleExit(context, provider),
      onPrimaryAction: () => provider.advanceStage(),
      onStop: () => provider.stopRun(),
      onReset: () => provider.resetApp(),
      onReRun: () {
        final runId = provider.selectedRunId;
        if (runId != null) provider.initiateReRun(runId);
      },
      onExport: () {
        // no-op in mock mode
      },
      onDelete: () {
        final runId = provider.selectedRunId;
        if (runId != null) _confirmDelete(context, provider, runId);
      },
    );
  }

  void _handleExit(BuildContext context, AppStateProvider provider) {
    _doExit(provider);
  }

  void _doExit(AppStateProvider provider) {
    final projectId = serviceLocator<String>(instanceName: 'projectId');

    if (projectId.isEmpty) {
      // No project created yet — go back to wherever the user came from.
      web.window.history.back();
    } else {
      // Project exists — navigate to its Tercen project screen.
      final teamId = Uri.base.queryParameters['teamId'] ?? '';
      final base = Uri.base;
      final projectUrl =
          '${base.scheme}://${base.host}/$teamId/p/$projectId';
      web.window.location.href = projectUrl;
    }
  }

  void _confirmDelete(
      BuildContext context, AppStateProvider provider, String runId) {
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
