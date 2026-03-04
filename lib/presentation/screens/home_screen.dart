import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../../domain/services/data_service.dart';

/// Home screen: assembles the Type 3 three-panel layout for
/// Flow Immunophenotyping - PhenoGraph.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStateProvider? _provider;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      _provider = context.read<AppStateProvider>();
      _provider!.addListener(_onProviderChanged);
      _provider!.loadData();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    final projectError = _provider?.projectCreationError;
    if (projectError != null && mounted) {
      _provider!.clearProjectCreationError();
      _showErrorDialog('Project Creation Failed', projectError);
      return;
    }

    final advanceError = _provider?.advanceError;
    if (advanceError != null && mounted) {
      _provider!.clearAdvanceError();
      _showErrorDialog('Processing Failed', advanceError);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppStateProvider>();

    return AppShell(
      appTitle: 'Flow Immunophenotyping',
      appIcon: SvgPicture.asset('assets/images/app_icon.svg', width: 20, height: 20),
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
        final runId = provider.selectedRunId;
        if (runId != null) _handleExport(context, runId);
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

  void _handleExport(BuildContext context, String runId) async {
    final dataService = serviceLocator<DataService>();

    // Show loading dialog while discovering files.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Finding export files…'),
          ],
        ),
      ),
    );

    try {
      final files = await dataService.getExportableFiles(runId);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No export files available for this run.')),
        );
        return;
      }

      // Show file list dialog.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: files.map((file) {
                final icon = _iconForFile(file.contentType, file.filename);
                return ListTile(
                  leading: Icon(icon),
                  title: Text(file.filename),
                  subtitle: Text(file.stepName),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _downloadFile(context, dataService, file.schemaId,
                        file.filename, file.contentType);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      _showErrorDialog('Export Failed', '$e');
    }
  }

  void _downloadFile(BuildContext context, DataService dataService,
      String schemaId, String filename, String contentType) async {
    try {
      final bytes = await dataService.downloadExportFile(schemaId, filename);
      _triggerBrowserDownload(bytes, filename, contentType);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Download Failed', '$e');
    }
  }

  void _triggerBrowserDownload(
      Uint8List bytes, String filename, String contentType) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: contentType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  IconData _iconForFile(String contentType, String filename) {
    final ct = contentType.toLowerCase();
    final fn = filename.toLowerCase();

    // PDF
    if (ct.contains('pdf') || fn.endsWith('.pdf')) return Icons.picture_as_pdf;
    // PowerPoint
    if (ct.contains('presentation') || ct.contains('ppt') ||
        fn.endsWith('.pptx') || fn.endsWith('.ppt')) {
      return Icons.slideshow;
    }
    // CSV / spreadsheet
    if (ct.contains('csv') || ct.contains('spreadsheet') ||
        fn.endsWith('.csv') || fn.endsWith('.tsv') || fn.endsWith('.xlsx')) {
      return Icons.table_chart;
    }
    // Markdown / text
    if (ct.contains('markdown') || fn.endsWith('.md') || fn.endsWith('.txt')) {
      return Icons.article;
    }
    // ZIP / archive
    if (ct.contains('zip') || ct.contains('gzip') || ct.contains('tar') ||
        fn.endsWith('.zip') || fn.endsWith('.gz')) {
      return Icons.folder_zip;
    }
    // FCS (flow cytometry)
    if (fn.endsWith('.fcs') || ct.contains('fcs') ||
        ct.contains('octet-stream')) {
      return Icons.science;
    }
    return Icons.insert_drive_file;
  }

  void _confirmDelete(
      BuildContext context, AppStateProvider provider, String runId) {
    final runName = provider.selectedRun?.name ?? runId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete run?'),
        content: Text(
          'Permanently delete "$runName" and its results?',
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
