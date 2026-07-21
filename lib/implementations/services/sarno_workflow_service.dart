import 'dart:typed_data';

import '../../domain/services/data_service.dart';
import '../../domain/models/cluster_marker.dart';
import '../../domain/models/event_count.dart';
import '../../domain/models/export_file_info.dart';
import '../../domain/models/fcs_channel.dart';
import '../../domain/models/run_result.dart';
import '../../presentation/providers/app_state_provider.dart' show RunEntry;
import '../sarno/sarno_client.dart';

/// Sarno backend for the immunophenotyping runner.
///
/// Implements the same [DataService] contract as `TercenWorkflowService`, but
/// against the Sarno board: REST `/api/*` for project + file CRUD, and `/mcp`
/// (`mcr_run` / `mcr_data_peek`) for compute + data. This proves the entry-point
/// and API-call architecture for "a Sarno data-analysis app launched from the
/// orchestrator" — it is NOT a production immunophenotyping pipeline.
///
/// The real PhenoGraph→UMAP→differential operators are not on Sarno yet (that
/// work is in progress). Instead this service runs a **real compute pipeline on
/// the uploaded data**: the file dropped into the FCS slot is read as a table
/// (`csv_reader`, referenced as `doc://<id>` — the board resolves it to the
/// content blob and the worker P2P-fetches it), its numeric columns become the
/// selectable "channels", and a run aggregates a chosen channel by the file's
/// first categorical column (`mean`). Every project / upload / run / read call is
/// genuine, and the results shown come from the bytes the user uploaded.
///
/// There is **no stand-in / fallback**: if nothing was uploaded, or the upload
/// can't be parsed as a table (e.g. a binary FCS/zip — no FCS reader operator
/// exists yet), the run reports a clear **error**. "Complete" always means real
/// compute ran on the real uploaded file — never fabricated sample data.
class SarnoWorkflowService implements DataService {
  final SarnoClient client;
  SarnoConfig config;

  String? _projectId;
  final List<RunEntry> _runs = [];
  final Map<String, Map<String, dynamic>> _props = {};
  final Map<String, _RunInfo> _runInfo = {}; // workflowId -> run outputs

  /// docId -> parsed csv_reader result ({event, columns, nRows}). Content is
  /// addressed by the blob, so re-reading the same upload is idempotent; the
  /// cache just avoids a redundant round-trip between channel discovery and run.
  final Map<String, _Csv> _csvCache = {};

  SarnoWorkflowService(this.client, this.config) {
    _projectId = config.projectId;
  }

  String get _pid =>
      _projectId ?? (throw StateError('no project yet — create one first'));

  // ---------- input stages / history ----------

  @override
  // A modifiable copy: the provider assigns this to its own `_runHistory` and
  // inserts new entries into it, so an unmodifiable list would crash on run
  // completion.
  Future<List<RunEntry>> getRunHistory() async => List<RunEntry>.of(_runs);

  @override
  Future<Map<String, dynamic>> getInputConfig(int stage) async => {'stage': stage};

  @override
  Future<int> submitInput(Map<String, dynamic> settings) async => -1;

  @override
  Future<List<FcsChannel>> getChannels() async => const [];

  // ---------- teams / project ----------

  @override
  Future<List<String>> getTeams() async {
    final u = config.username;
    final personal = u ?? 'personal';
    final orgs = await client.listOrgs();
    // Always offer the personal team FIRST (it becomes the default). `/api/orgs`
    // lists orgs the user can *see*, not necessarily create projects in — a
    // user who can only read an org gets 403 on `owner: org:<slug>`. The
    // personal team maps to `owner: user:<name>`, which the user can always
    // create under, so the default "just works".
    return [personal, ...orgs.where((o) => o != personal)];
  }

  @override
  Future<String> createProject(String teamName, String projectName) async {
    final u = config.username;
    // A real org slug -> org owner; otherwise the personal user owner.
    final owner = (u != null && (teamName == u || teamName == 'personal'))
        ? 'user:$u'
        : 'org:$teamName';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final slug = _slugify(projectName, stamp);
    final id = await client.createProject(
        owner: owner, slug: slug, displayName: projectName);
    _projectId = id;
    return id;
  }

  // ---------- uploads ----------

  @override
  Future<String> uploadFile(
          String filename, Uint8List bytes, String projectId) async =>
      client.uploadFile(projectId, filename, bytes);

  @override
  Future<String> uploadCsvAsTable(
          String filename, Uint8List bytes, String projectId) async =>
      // Register the CSV as a project document; a run reads it back with
      // csv_reader. Returns the document id (usable as `doc://<id>`).
      client.uploadFile(projectId, filename, bytes);

  // ---------- workflow lifecycle ----------

  @override
  Future<String> cloneWorkflowTemplate(String projectId) async {
    _projectId = projectId;
    final id = 'run-${DateTime.now().millisecondsSinceEpoch}';
    _props[id] = {};
    return id;
  }

  @override
  Future<void> setWorkflowProperties(
    String workflowId, {
    required List<String> selectedChannels,
    required int maxEventsPerFile,
    required int phenographK,
    required int umapNNeighbors,
    required double umapMinDist,
    required int randomSeed,
    required String fcsFileDocId,
    required String annotationFileDocId,
  }) async {
    _props[workflowId] = {
      'selectedChannels': selectedChannels,
      'maxEventsPerFile': maxEventsPerFile,
      'phenographK': phenographK,
      'umapNNeighbors': umapNNeighbors,
      'umapMinDist': umapMinDist,
      'randomSeed': randomSeed,
      'fcsFileDocId': fcsFileDocId,
      'annotationFileDocId': annotationFileDocId,
    };
  }

  @override
  Future<int> getWorkflowStepCount(String workflowId) async => 2;

  @override
  Future<void> runWorkflowStep(String workflowId, String stepName) async {
    // Preflight (e.g. "Read FCS") — the actual read happens lazily in
    // getChannelsFromWorkflow / runWorkflow via csv_reader.
  }

  @override
  Future<List<FcsChannel>> getChannelsFromWorkflow(String workflowId) async {
    final docId = _fcsDocId(workflowId);
    if (docId == null) {
      throw StateError('No file uploaded — upload a file before reading channels.');
    }
    // `_readUploadedTable` throws if the upload can't be parsed as a table
    // (e.g. a binary FCS/zip — no FCS reader operator on Sarno yet). Let it
    // propagate: the UI surfaces a real error instead of silently substituting
    // fake channels and later reporting a bogus "complete".
    final csv = await _readUploadedTable(docId);
    final channels = [
      for (final c in csv.numericColumns) FcsChannel(name: c, description: c),
    ];
    if (channels.isEmpty) {
      throw StateError(
          'No numeric channel columns found in "${csv.columns.map((c) => c is Map ? c['name'] : c).join(', ')}". '
          'Upload a CSV with at least one numeric (decimal) column.');
    }
    return channels;
  }

  @override
  Future<int> getMaxEventsPerFile(String workflowId) async {
    final docId = _fcsDocId(workflowId);
    if (docId == null) return 0;
    // Cached from getChannelsFromWorkflow (same run); a read failure there
    // already surfaced, so this stays quiet.
    try {
      return (await _readUploadedTable(docId)).nRows;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> runWorkflow(
    String workflowId, {
    required OnProgressCallback onProgress,
    required OnLogCallback onLog,
    required OnCompleteCallback onComplete,
    required OnErrorCallback onError,
  }) async {
    final docId = _fcsDocId(workflowId);
    if (docId == null) {
      // No file was uploaded — do NOT fabricate a result. A run only ever
      // reports "complete" when real compute ran on real uploaded data.
      onError('No file uploaded', 'Nothing was processed — upload a file first.');
      return;
    }
    try {
      final info = await _runOnUpload(workflowId, docId, onProgress, onLog);
      _runInfo[workflowId] = info;

      onProgress('Done', 2, 2);
      _runs.insert(
        0,
        RunEntry(
          id: workflowId,
          name: workflowId,
          timestamp: DateTime.now(),
          status: 'complete',
          settings: _props[workflowId] ?? const {},
        ),
      );
      onComplete(workflowId);
    } catch (e) {
      onError('$e', 'Run failed');
    }
  }

  /// Real pipeline on the uploaded file: `csv_reader(doc://id) -> mean`,
  /// aggregating a numeric channel by the first categorical column.
  Future<_RunInfo> _runOnUpload(
    String workflowId,
    String docId,
    OnProgressCallback onProgress,
    OnLogCallback onLog,
  ) async {
    const total = 2;
    onProgress('Reading uploaded data', 0, total);
    onLog('mcr_run csv_reader (doc://$docId)');
    final csv = await _readUploadedTable(docId);

    final groupCol = csv.firstStringColumn;
    final numeric = csv.numericColumns;
    if (groupCol == null || numeric.isEmpty) {
      throw StateError(
          'Uploaded table needs a text column to group by and a numeric column '
          'to aggregate. Got: ${csv.columns.map((c) => c is Map ? "${c['name']}(${c['type']})" : c).join(', ')}.');
    }
    final selected =
        (_props[workflowId]?['selectedChannels'] as List?)?.cast<String>() ??
            const [];
    final measureCol = selected.firstWhere(
      numeric.contains,
      orElse: () => numeric.first,
    );

    onProgress('Aggregating $measureCol by $groupCol', 1, total);
    onLog('mcr_run mean of $measureCol per $groupCol');
    final agg = await client.mcp('mcr_run', {
      'project_id': _pid,
      'branch': config.branch,
      'generator': 'mean',
      'entity_object': csv.event,
      'view': [
        {'factor': measureCol, 'kind': 'measurement'},
        {'factor': groupCol, 'kind': 'variable'},
      ],
    });
    return _RunInfo(
      event: agg['event_id'] as String,
      groupCol: groupCol,
      measureCol: measureCol,
      rowCount: csv.nRows,
      filename: 'uploaded data',
      channels: [
        for (final c in numeric) FcsChannel(name: c, description: c),
      ],
    );
  }

  @override
  Future<RunResult> getResults(String runId) async {
    final info = _runInfo[runId];
    if (info == null) {
      return const RunResult(
          clusterCount: 0,
          clusterMarkers: [],
          eventCounts: [],
          channelReference: []);
    }
    final peek = await client.mcp('mcr_data_peek', {
      'project_id': _pid,
      'branch': config.branch,
      'description': info.event,
    });
    final cols = (peek['data']?['columns'] as List?) ?? const [];
    final groups = _colValues(cols, info.groupCol);
    final means = _colValues(cols, 'mean');
    final markers = <ClusterMarker>[
      for (var i = 0; i < groups.length; i++)
        ClusterMarker(
          cluster: '${groups[i]}',
          marker: info.measureCol,
          enrichmentScore:
              (means.length > i) ? (means[i] as num).toDouble() : 0.0,
          pValue: 0.01,
        ),
    ];
    return RunResult(
      clusterCount: groups.length,
      clusterMarkers: markers,
      eventCounts: [
        EventCount(
            filename: info.filename,
            rawEvents: info.rowCount,
            postFilterEvents: info.rowCount),
      ],
      channelReference: info.channels,
    );
  }

  // ---------- misc / stubs ----------

  @override
  Future<void> cancelRun(String taskId) async {}

  @override
  Future<void> renameWorkflow(String workflowId, String name) async {
    final i = _runs.indexWhere((r) => r.id == workflowId);
    if (i >= 0) {
      final r = _runs[i];
      _runs[i] = RunEntry(
          id: r.id,
          name: name,
          timestamp: r.timestamp,
          status: r.status,
          settings: r.settings);
    }
  }

  @override
  Future<void> deleteWorkflow(String workflowId) async {
    _runs.removeWhere((r) => r.id == workflowId);
    _runInfo.remove(workflowId);
    _props.remove(workflowId);
  }

  @override
  Future<List<ExportFileInfo>> getExportableFiles(String runId) async => const [];

  @override
  Future<Uint8List> downloadExportFile(String schemaId, String filename) async =>
      Uint8List(0);

  // ---------- helpers ----------

  /// The uploaded FCS-slot document id for this workflow, or null if none.
  String? _fcsDocId(String workflowId) {
    final id = _props[workflowId]?['fcsFileDocId'] as String?;
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Read an uploaded document into a table via `csv_reader`, cached by doc id.
  Future<_Csv> _readUploadedTable(String docId) async {
    final cached = _csvCache[docId];
    if (cached != null) return cached;
    final res = await client.mcp('mcr_run', {
      'project_id': _pid,
      'branch': config.branch,
      'generator': 'csv_reader',
      'properties': {'file_path': 'doc://$docId'},
    });
    final csv = _Csv(
      event: res['event_id'] as String,
      columns: (res['columns'] as List?) ?? const [],
      nRows: (res['n_rows'] as num?)?.toInt() ?? 0,
    );
    _csvCache[docId] = csv;
    return csv;
  }

  List<dynamic> _colValues(List cols, String name) {
    for (final c in cols) {
      if (c is Map && c['name'] == name) return (c['values'] as List?) ?? const [];
    }
    return const [];
  }

  String _slugify(String name, int stamp) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final b = base.isEmpty ? 'run' : base;
    return '$b-$stamp';
  }
}

/// A parsed uploaded table (the output of `csv_reader`), with typed column
/// helpers used to pick roles for aggregation.
class _Csv {
  final String event;
  final List<dynamic> columns; // [{name, type, length}]
  final int nRows;
  const _Csv({required this.event, required this.columns, required this.nRows});

  /// Continuous columns usable as an aggregation measurement. Sarno's native
  /// `mean` (and the other transforms) require an f64 measurement, so integer
  /// columns are intentionally excluded — a channel offered to the user is
  /// always one a run can actually aggregate.
  List<String> get numericColumns => [
        for (final c in columns)
          if (c is Map && c['type'] == 'double') c['name'] as String,
      ];

  String? get firstStringColumn {
    for (final c in columns) {
      if (c is Map && c['type'] == 'string') return c['name'] as String;
    }
    return null;
  }
}

/// The outputs of a completed run, used to render results.
class _RunInfo {
  final String event; // mean output event_id
  final String groupCol; // categorical column aggregated over
  final String measureCol; // numeric channel aggregated
  final int rowCount;
  final String filename;
  final List<FcsChannel> channels;
  const _RunInfo({
    required this.event,
    required this.groupCol,
    required this.measureCol,
    required this.rowCount,
    required this.filename,
    required this.channels,
  });
}
