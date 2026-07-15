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
/// The real PhenoGraph→UMAP→differential operators are not on Sarno; until they
/// are re-authored as container operators, `runWorkflow` executes a **stand-in
/// pipeline** (`sample_dataset` → `mean`) using operators that already exist.
/// Every project/upload/run/read call it makes is genuine.
class SarnoWorkflowService implements DataService {
  final SarnoClient client;
  SarnoConfig config;

  String? _projectId;
  final List<RunEntry> _runs = [];
  final Map<String, Map<String, dynamic>> _props = {};
  final Map<String, String> _runOutputEvent = {}; // workflowId -> event_id

  SarnoWorkflowService(this.client, this.config) {
    _projectId = config.projectId;
  }

  String get _pid =>
      _projectId ?? (throw StateError('no project yet — create one first'));

  // ---------- input stages / history ----------

  @override
  Future<List<RunEntry>> getRunHistory() async => List.unmodifiable(_runs);

  @override
  Future<Map<String, dynamic>> getInputConfig(int stage) async => {'stage': stage};

  @override
  Future<int> submitInput(Map<String, dynamic> settings) async => -1;

  @override
  Future<List<FcsChannel>> getChannels() async => _standInChannels();

  // ---------- teams / project ----------

  @override
  Future<List<String>> getTeams() async {
    final orgs = await client.listOrgs();
    if (orgs.isNotEmpty) return orgs;
    // Portable/user-scoped token with no orgs: offer a personal "team".
    final u = config.username;
    return [u == null ? 'personal' : u];
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
      // Stand-in: register the CSV as a project document; a real port would
      // parse it (csv_reader) into a table output. Returns the document id.
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
    // Preflight (e.g. "Read FCS") — no-op for the stand-in pipeline.
  }

  @override
  Future<List<FcsChannel>> getChannelsFromWorkflow(String workflowId) async =>
      _standInChannels();

  @override
  Future<int> getMaxEventsPerFile(String workflowId) async => 15;

  @override
  Future<void> runWorkflow(
    String workflowId, {
    required OnProgressCallback onProgress,
    required OnLogCallback onLog,
    required OnCompleteCallback onComplete,
    required OnErrorCallback onError,
  }) async {
    // Stand-in pipeline (sample_dataset -> mean) via /mcp. mcr_run is
    // synchronous, so progress is emitted around each step.
    try {
      const total = 2;
      onProgress('Generating dataset', 0, total);
      onLog('mcr_run sample_dataset (iris)');
      final gen = await client.mcp('mcr_run', {
        'project_id': _pid,
        'branch': config.branch,
        'generator': 'sample_dataset',
        'properties': {'name': 'iris'},
      });
      final ev0 = gen['event_id'] as String;

      onProgress('Aggregating clusters', 1, total);
      onLog('mcr_run mean per group');
      final agg = await client.mcp('mcr_run', {
        'project_id': _pid,
        'branch': config.branch,
        'generator': 'mean',
        'entity_object': ev0,
        'view': [
          {'factor': 'sepal_length', 'kind': 'measurement'},
          {'factor': 'species', 'kind': 'variable'},
        ],
      });
      _runOutputEvent[workflowId] = agg['event_id'] as String;

      onProgress('Done', total, total);
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
      onError('$e', 'Stand-in pipeline failed');
    }
  }

  @override
  Future<RunResult> getResults(String runId) async {
    final ev = _runOutputEvent[runId];
    if (ev == null) {
      return const RunResult(
          clusterCount: 0,
          clusterMarkers: [],
          eventCounts: [],
          channelReference: []);
    }
    final peek = await client.mcp('mcr_data_peek', {
      'project_id': _pid,
      'branch': config.branch,
      'description': ev,
    });
    final cols = (peek['data']?['columns'] as List?) ?? const [];
    final groups = _colValues(cols, 'species');
    final means = _colValues(cols, 'mean');
    final markers = <ClusterMarker>[];
    for (var i = 0; i < groups.length; i++) {
      markers.add(ClusterMarker(
        cluster: '${groups[i]}',
        marker: 'sepal_length',
        enrichmentScore: (means.length > i)
            ? (means[i] as num).toDouble()
            : 0.0,
        pValue: 0.01,
      ));
    }
    return RunResult(
      clusterCount: groups.length,
      clusterMarkers: markers,
      eventCounts: const [EventCount(filename: 'iris', rawEvents: 15, postFilterEvents: 15)],
      channelReference: _standInChannels(),
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
    _runOutputEvent.remove(workflowId);
    _props.remove(workflowId);
  }

  @override
  Future<List<ExportFileInfo>> getExportableFiles(String runId) async => const [];

  @override
  Future<Uint8List> downloadExportFile(String schemaId, String filename) async =>
      Uint8List(0);

  // ---------- helpers ----------

  List<dynamic> _colValues(List cols, String name) {
    for (final c in cols) {
      if (c is Map && c['name'] == name) return (c['values'] as List?) ?? const [];
    }
    return const [];
  }

  List<FcsChannel> _standInChannels() => const [
        FcsChannel(name: 'sepal_length', description: 'Sepal length'),
        FcsChannel(name: 'sepal_width', description: 'Sepal width'),
        FcsChannel(name: 'petal_length', description: 'Petal length'),
        FcsChannel(name: 'petal_width', description: 'Petal width'),
      ];

  String _slugify(String name, int stamp) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final b = base.isEmpty ? 'run' : base;
    return '$b-$stamp';
  }
}
