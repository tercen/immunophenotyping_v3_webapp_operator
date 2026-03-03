import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:sci_tercen_client/sci_client_service_factory.dart';
import 'package:sci_tercen_client/sci_client.dart' hide ServiceFactory;
import '../../domain/models/cluster_marker.dart';
import '../../domain/models/event_count.dart';
import '../../domain/models/fcs_channel.dart';
import '../../domain/models/run_result.dart';
import '../../domain/services/data_service.dart';
import '../../presentation/providers/app_state_provider.dart';

/// Template workflow GitHub URL and version — same identifiers used by V2.
/// These match the template registered in the Tercen Site/Main Library.
const _templateWorkflowUrl = 'https://github.com/tercen/immunophenotyping_template';
const _templateWorkflowVersion = '2.3.0';

/// Fallback: display name used only for error messages.
const _templateWorkflowName = 'Flow Immunophenotyping - PhenoGraph';

/// Stable TableStep IDs for the immunophenotyping template (v2.3.0).
/// These IDs are preserved when copyApp() clones the workflow, so we
/// match by ID rather than by name (names include the original filename).
const _fcsTableStepId = '8346b5cb-5e4d-41ae-be35-313abe9500d0';
const _annotationTableStepId = '15594fff-3f9f-4419-8d75-560034bc02e7';

/// Real Tercen data service for Flow E (Type 3 workflow manager).
///
/// Uses entity services directly — no OperatorContext.
/// Each "run" is a cloned workflow in the project.
class TercenWorkflowService implements DataService {
  final ServiceFactory _factory;
  String _projectId;

  /// Cache the template workflow ID after first lookup.
  String? _templateWorkflowId;

  /// Track the running task ID for cancellation.
  String? _runningTaskId;

  TercenWorkflowService(this._factory, this._projectId);

  // =============================================
  // Run history — list cloned workflows in project
  // =============================================

  @override
  Future<List<RunEntry>> getRunHistory() async {
    if (_projectId.isEmpty) return [];
    try {
      final allDocs = await _factory.projectDocumentService
          .findProjectObjectsByLastModifiedDate(
        startKey: [_projectId, ''],
        endKey: [_projectId, '\uf000'],
        useFactory: true,
      );
      final workflows =
          allDocs.whereType<Workflow>().toList();

      final entries = <RunEntry>[];
      for (final wf in workflows) {
        // Skip the template itself
        if (wf.name == _templateWorkflowName) continue;

        final status = _determineWorkflowStatus(wf);
        final settings = await _extractSettingsFromWorkflow(wf);

        entries.add(RunEntry(
          id: wf.id,
          name: wf.name,
          timestamp: DateTime.tryParse(wf.lastModifiedDate.value) ??
              DateTime.now(),
          status: status,
          settings: settings,
        ));
      }

      // Most recent first
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (e) {
      print('Tercen error in getRunHistory: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  /// Determine workflow status from step states.
  String _determineWorkflowStatus(Workflow wf) {
    bool anyFailed = false;
    bool anyRunning = false;
    bool allDone = true;

    for (final step in wf.steps) {
      final taskState = step.state.taskState;
      if (taskState is FailedState) {
        anyFailed = true;
        allDone = false;
      } else if (taskState is RunningState || taskState is PendingState) {
        anyRunning = true;
        allDone = false;
      } else if (taskState is! DoneState) {
        allDone = false;
      }
    }

    if (anyFailed) return 'error';
    if (anyRunning) return 'running';
    if (allDone && wf.steps.isNotEmpty) return 'complete';
    return 'stopped';
  }

  /// Extract settings summary from workflow step properties.
  Future<Map<String, dynamic>> _extractSettingsFromWorkflow(
      Workflow wf) async {
    final settings = <String, dynamic>{};

    for (final step in wf.steps) {
      if (step is! DataStep) continue;
      final props = step.model.operatorSettings.operatorRef.propertyValues;
      for (final pv in props) {
        settings[pv.name] = pv.value;
      }
    }

    return settings;
  }

  // =============================================
  // Results — read step outputs from a workflow
  // =============================================

  @override
  Future<RunResult> getResults(String workflowId) async {
    try {
      final wf = await _factory.workflowService.get(workflowId);

      // Find the failed step if any
      String? failedStep;
      String? errorMessage;
      for (final step in wf.steps) {
        if (step.state.taskState is FailedState) {
          final failed = step.state.taskState as FailedState;
          failedStep = step.name;
          errorMessage = '${failed.error}: ${failed.reason}';
          break;
        }
      }

      // Read cluster markers from enrichment score step output
      final clusterMarkers = await _readClusterMarkers(wf);

      // Read event counts from downsample/QC step output
      final eventCounts = await _readEventCounts(wf);

      // Read channel reference
      final channels = await _readChannelReference(wf);

      // Count clusters from PhenoGraph output
      final clusterCount = _countUniqueClusters(clusterMarkers);

      return RunResult(
        clusterCount: clusterCount,
        clusterMarkers: clusterMarkers,
        eventCounts: eventCounts,
        channelReference: channels,
        errorMessage: errorMessage,
        failedStep: failedStep,
      );
    } catch (e) {
      print('Tercen error in getResults: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  int _countUniqueClusters(List<ClusterMarker> markers) {
    return markers.map((m) => m.cluster).toSet().length;
  }

  /// Read cluster marker enrichment data from the workflow step output.
  Future<List<ClusterMarker>> _readClusterMarkers(Workflow wf) async {
    try {
      final table = await _readStepOutput(wf, 'Marker Enrichment Score');
      if (table == null) return [];

      final clusters = _getColumnValues<String>(table, 'cluster');
      final markers = _getColumnValues<String>(table, 'marker');
      final scores = _getColumnValues<double>(table, 'enrichmentScore');
      final pValues = _getColumnValues<double>(table, 'pValue');

      if (clusters == null || markers == null) return [];

      final results = <ClusterMarker>[];
      for (int i = 0; i < clusters.length; i++) {
        results.add(ClusterMarker(
          cluster: clusters[i],
          marker: markers[i],
          enrichmentScore: scores != null && i < scores.length ? scores[i] : 0,
          pValue: pValues != null && i < pValues.length ? pValues[i] : 1,
        ));
      }
      return results;
    } catch (e) {
      print('Warning: could not read cluster markers: $e');
      return [];
    }
  }

  /// Read event count data from the workflow step output.
  Future<List<EventCount>> _readEventCounts(Workflow wf) async {
    try {
      final table = await _readStepOutput(wf, 'Downsample');
      if (table == null) return [];

      final filenames = _getColumnValues<String>(table, 'filename');
      final rawEvents = _getColumnValues<int>(table, 'rawEvents');
      final postFilter = _getColumnValues<int>(table, 'postFilterEvents');

      if (filenames == null) return [];

      final results = <EventCount>[];
      for (int i = 0; i < filenames.length; i++) {
        results.add(EventCount(
          filename: filenames[i],
          rawEvents: rawEvents != null && i < rawEvents.length
              ? rawEvents[i]
              : 0,
          postFilterEvents: postFilter != null && i < postFilter.length
              ? postFilter[i]
              : 0,
        ));
      }
      return results;
    } catch (e) {
      print('Warning: could not read event counts: $e');
      return [];
    }
  }

  /// Read the FCS channel list from the workflow.
  ///
  /// Preferred: "Channel names and descriptions" step output has a proper
  /// name+description row per channel — available after the full pipeline runs.
  ///
  /// Fallback: "Read FCS" step output has one column per FCS channel; the
  /// column names are the channel names. Available immediately after Stage 1
  /// preflight (only "Read FCS" has run).
  /// Read FCS channel names from the "Read FCS" step's "Variables" schema.
  ///
  /// The "Read FCS" operator outputs multiple relations. The "Variables"
  /// schema is a small lookup table (~30 rows) with columns:
  ///   channel_name        — raw FCS parameter name ($PnN, e.g. "BV421-A")
  ///   channel_description — human-readable label ($PnS, e.g. "CD3")
  ///
  /// V2 pattern: find schema named "Variables", select name+description cols.
  /// Throws if the step hasn't run or the Variables schema is missing.
  Future<List<FcsChannel>> _readChannelReference(Workflow wf) async {
    // 1. Find the Read FCS DataStep
    DataStep? readFcsStep;
    for (final step in wf.steps) {
      if (step is DataStep && step.name == 'Read FCS') {
        readFcsStep = step;
        break;
      }
    }
    if (readFcsStep == null) {
      throw StateError('"Read FCS" step not found in workflow.');
    }
    if (readFcsStep.state.taskState is! DoneState) {
      throw StateError('"Read FCS" step has not completed.');
    }

    // 2. Walk the relation tree to get all schema IDs
    final relations = _getSimpleRelations(readFcsStep.computedRelation);
    if (relations.isEmpty) {
      throw StateError('"Read FCS" step has no output relations.');
    }

    // 3. Fetch all schemas and find the one named "Variables"
    final schemaIds = relations.map((r) => r.id).toList();
    final schemas = await _factory.tableSchemaService.list(schemaIds);

    Schema? variablesSchema;
    for (final sch in schemas) {
      if (sch.name == 'Variables') {
        variablesSchema = sch;
        break;
      }
    }
    if (variablesSchema == null || variablesSchema.nRows == 0) {
      throw StateError(
          '"Read FCS" output has no "Variables" schema. '
          'Available schemas: ${schemas.map((s) => '"${s.name}" (${s.nRows} rows)').join(', ')}');
    }

    // 4. Find the name and description columns (V2 uses .contains())
    final nameCol = variablesSchema.columns
        .where((c) => c.name.contains('name') && !c.name.contains('description'))
        .firstOrNull;
    final descCol = variablesSchema.columns
        .where((c) => c.name.contains('description'))
        .firstOrNull;

    if (nameCol == null) {
      throw StateError(
          '"Variables" schema has no column containing "name". '
          'Columns: ${variablesSchema.columns.map((c) => c.name).join(', ')}');
    }

    // 5. SELECT the columns from the Variables table
    final colsToSelect = <String>[nameCol.name];
    if (descCol != null) colsToSelect.add(descCol.name);

    final table = await _factory.tableSchemaService.select(
      variablesSchema.id,
      colsToSelect,
      0,
      variablesSchema.nRows,
    );

    // 6. Extract values
    final names = _getColumnValues<String>(table, nameCol.name);
    if (names == null || names.isEmpty) {
      throw StateError('"Variables" schema "${nameCol.name}" column is empty.');
    }

    final descriptions = descCol != null
        ? _getColumnValues<String>(table, descCol.name)
        : null;

    // 7. Build FcsChannel list
    final channels = <FcsChannel>[];
    for (int i = 0; i < names.length; i++) {
      final name = names[i];
      final desc = (descriptions != null && i < descriptions.length)
          ? descriptions[i]
          : name;
      channels.add(FcsChannel(
        name: name,
        description: desc,
        isQc: _isQcChannel(name, desc),
      ));
    }
    return channels;
  }

  bool _isQcChannel(String name, String description) {
    final lower = name.toLowerCase();
    return lower.startsWith('fsc') ||
        lower.startsWith('ssc') ||
        lower == 'time' ||
        lower.contains('viability') ||
        description.toLowerCase().contains('viability');
  }

  // =============================================
  // Channels — from FCS data in project
  // =============================================

  @override
  Future<List<FcsChannel>> getChannels() async {
    if (_projectId.isEmpty) return [];
    try {
      final history = await getRunHistory();
      if (history.isNotEmpty) {
        final wf = await _factory.workflowService.get(history.first.id);
        return _readChannelReference(wf);
      }
      return [];
    } catch (e) {
      print('Tercen error in getChannels: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getInputConfig(int stage) async {
    return {'stage': stage};
  }

  @override
  Future<int> submitInput(Map<String, dynamic> settings) async {
    return -1;
  }

  // =============================================
  // Phase 3: Team listing
  // =============================================

  @override
  Future<List<String>> getTeams() async {
    try {
      // The username must be passed explicitly — get('') sends id= (empty)
      // which returns 404. Extract the username from the Tercen JWT token
      // that is always present in the URL query string.
      final username = _usernameFromToken();
      if (username == null || username.isEmpty) {
        throw StateError('Could not determine username from URL token');
      }

      // useFactory: true gives the concrete subclass with teamAcl populated.
      final user =
          await _factory.userService.get(username, useFactory: true);

      final teamNames = <String>[];
      for (final ace in user.teamAcl.aces) {
        if (ace.principals.isNotEmpty) {
          teamNames.add(ace.principals[0].principalId);
        }
      }

      // Sort alphabetically, then put the user's own name first (home team).
      teamNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      teamNames.remove(username);
      teamNames.insert(0, username);

      return teamNames;
    } catch (e) {
      print('Tercen error in getTeams: $e');
      rethrow;
    }
  }

  /// Parse the Tercen JWT token from the URL and return the username (`u`
  /// field inside the `data` claim).  Returns null if anything fails.
  String? _usernameFromToken() {
    try {
      final token = Uri.base.queryParameters['token'];
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      return (claims['data'] as Map<String, dynamic>?)?['u'] as String?;
    } catch (_) {
      return null;
    }
  }

  // =============================================
  // Phase 3: Project creation
  // =============================================

  @override
  Future<String> createProject(String teamName, String projectName) async {
    try {
      final project = Project()
        ..name = projectName
        ..acl.owner = teamName;
      final created = await _factory.projectService.create(project);
      _projectId = created.id;
      return created.id;
    } catch (e) {
      print('Tercen error in createProject: $e');
      rethrow;
    }
  }

  // =============================================
  // Phase 3: File upload
  // =============================================

  @override
  Future<String> uploadFile(
      String filename, Uint8List bytes, String projectId) async {
    try {
      final fileDoc = FileDocument()
        ..name = filename
        ..projectId = projectId;
      final uploaded = await _factory.fileService
          .upload(fileDoc, Stream.value(bytes));
      return uploaded.id;
    } catch (e) {
      print('Tercen error in uploadFile: $e');
      rethrow;
    }
  }

  // =============================================
  // Phase 3: CSV-to-table upload (annotation files)
  // =============================================

  @override
  Future<String> uploadCsvAsTable(
      String filename, Uint8List bytes, String projectId) async {
    try {
      // V2 pattern (webapp_lib upload_table_component.dart uploadFileAsTable):
      //  1. FileDocument with CSVFileMetadata set BEFORE upload
      //  2. Pre-parse CSV to create a Schema with ColumnSchema entries
      //  3. CSVTask with schema + CSVParserParam + state=InitState

      final separator = filename.toLowerCase().endsWith('.tsv') ? '\t' : ',';
      final contentType =
          separator == '\t' ? 'text/tab-separated-values' : 'text/csv';

      // 1. Upload file with CSV metadata on the FileDocument
      final metadata = CSVFileMetadata()
        ..separator = separator
        ..quote = '"'
        ..contentType = contentType
        ..contentEncoding = 'utf-8';
      final fileDoc = FileDocument()
        ..name = filename
        ..projectId = projectId
        ..metadata = metadata;
      final uploaded = await _factory.fileService
          .upload(fileDoc, Stream.value(bytes));

      // 2. Get project owner
      final project = await _factory.projectService.get(projectId);

      // 3. Pre-parse CSV headers from bytes to build a Schema
      final inputSchema = _createSchemaFromBytes(
        bytes,
        separator: separator,
        filename: filename,
        projectId: projectId,
        owner: project.acl.owner,
      );

      // 4. Create CSVTask with schema + params
      final params = CSVParserParam()
        ..separator = separator
        ..encoding = 'utf-8'
        ..quote = '"'
        ..hasHeaders = true
        ..allowMalformed = true
        ..comment = '';
      var csvTask = CSVTask()
        ..state = InitState()
        ..fileDocumentId = uploaded.id
        ..projectId = projectId
        ..owner = project.acl.owner
        ..schema = inputSchema
        ..params = params;
      csvTask = await _factory.taskService.create(csvTask) as CSVTask;
      await _factory.taskService.runTask(csvTask.id);
      final doneTask = await _factory.taskService.waitDone(csvTask.id);

      if (doneTask.state is FailedState) {
        final failed = doneTask.state as FailedState;
        throw Exception('CSVTask failed: ${failed.error}: ${failed.reason}');
      }

      // 5. Return the schema ID from the completed CSVTask
      final csvDone = doneTask as CSVTask;
      if (csvDone.schemaId.isEmpty) {
        throw StateError('CSVTask completed but returned no schemaId');
      }
      return csvDone.schemaId;
    } catch (e) {
      print('Tercen error in uploadCsvAsTable: $e');
      rethrow;
    }
  }

  /// Pre-parse CSV bytes to build a Schema with ColumnSchema entries.
  /// V2's _createFileSchema downloads the file and parses; since we already
  /// have the bytes in memory we parse directly.
  Schema _createSchemaFromBytes(
    Uint8List bytes, {
    required String separator,
    required String filename,
    required String projectId,
    required String owner,
  }) {
    final text = utf8.decode(bytes);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw StateError('CSV file is empty');
    }

    final headers = lines.first.split(separator).map((h) => h.trim()).toList();
    // Sample up to 5 data rows to infer column types
    final dataRows = lines.length > 1 ? lines.sublist(1, math.min(6, lines.length)) : <String>[];

    final schema = Schema()
      ..name = filename
      ..projectId = projectId
      ..acl.owner = owner;

    for (int i = 0; i < headers.length; i++) {
      final colName = headers[i];
      // Infer type from sample values
      String colType = 'string';
      if (dataRows.isNotEmpty) {
        final values = dataRows.map((row) {
          final cells = row.split(separator);
          return i < cells.length ? cells[i].trim() : '';
        }).where((v) => v.isNotEmpty);
        if (values.isNotEmpty && values.every((v) => double.tryParse(v) != null)) {
          colType = 'double';
        }
      }
      schema.columns.add(ColumnSchema()
        ..name = colName
        ..type = colType);
    }

    return schema;
  }

  // =============================================
  // Phase 3: Workflow cloning
  // =============================================

  @override
  Future<String> cloneWorkflowTemplate(String projectId) async {
    try {
      final templateId = await _findTemplateWorkflowId();

      // copyApp returns a prepared workflow body — not yet persisted.
      // V2 pattern (immunophenotyping_v2_webapp_operator settings_screen.dart):
      //   runWorkflow = await factory.workflowService.copyApp(templateId, projectId);
      //   runWorkflow = await factory.workflowService.create(runWorkflow);
      // Do NOT modify workflow.acl — copyApp already sets ownership correctly
      // on the server side. Touching acl causes a JS-level null crash.
      final workflow =
          await _factory.workflowService.copyApp(templateId, projectId);
      final created = await _factory.workflowService.create(workflow);
      return created.id;
    } catch (e) {
      print('Tercen error in cloneWorkflowTemplate: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  /// Find the template workflow ID by searching library teams first, then
  /// falling back to the current project (for in-project installs).
  ///
  /// Tercen stores shared workflow templates in library teams (Site Library,
  /// Main Library), not in user projects. The [documentService.getLibrary]
  /// call searches across all accessible library teams.
  Future<String> _findTemplateWorkflowId() async {
    if (_templateWorkflowId != null) return _templateWorkflowId!;

    // Primary: search all library teams (Site Library, Main Library).
    try {
      final libDocs = await _factory.documentService.getLibrary(
        '',              // projectId: empty = not scoped to a project
        const [],        // teamIds: empty = all accessible teams
        const ['Workflow'], // only workflow documents
        const [],        // tags: no filter
        0,               // offset
        -1,              // limit: -1 = all results
      );

      // getLibrary() returns List<Document> (base objects), not List<Workflow>.
      // Match by URL + version — same approach used by V2 via webapp_utils.
      // doc.url.uri is the primary URL; doc.urls is a list of additional URLs.
      print('Library search returned ${libDocs.length} documents:');
      for (final doc in libDocs) {
        print('  doc: "${doc.name}" v${doc.version} url=${doc.url.uri} (id=${doc.id})');
      }

      final match = libDocs.where((doc) {
        final versionMatch = doc.version == _templateWorkflowVersion;
        final urlMatch = doc.url.uri == _templateWorkflowUrl ||
            doc.urls.any((u) => u.uri == _templateWorkflowUrl);
        return versionMatch && urlMatch;
      }).firstOrNull;

      if (match != null) {
        // V2 resolves the Document ID to a full Workflow via workflowService.list()
        // before passing to copyApp. This resolution step is required.
        print('Library match: "${match.name}" id=${match.id}');
        final resolved = await _factory.workflowService.list([match.id]);
        if (resolved.isNotEmpty) {
          _templateWorkflowId = resolved.first.id;
          print('Resolved workflow id: $_templateWorkflowId');
          return _templateWorkflowId!;
        }
        print('workflowService.list returned empty for id=${match.id}');
      }
    } catch (e) {
      print('Library search failed (will try project fallback): $e');
    }

    // Fallback: search within the current project.
    final allDocs = await _factory.projectDocumentService
        .findProjectObjectsByLastModifiedDate(
      startKey: [_projectId, ''],
      endKey: [_projectId, '\uf000'],
      useFactory: true,
    );
    final workflows = allDocs
        .whereType<Workflow>()
        .where((wf) => wf.name == _templateWorkflowName)
        .toList();

    if (workflows.isEmpty) {
      throw StateError(
          'Template workflow "$_templateWorkflowName" not found in libraries '
          'or project $_projectId. '
          'Please ensure the immunophenotyping template is installed in your '
          'Tercen library (Site Library or Main Library).');
    }

    _templateWorkflowId = workflows.first.id;
    return _templateWorkflowId!;
  }

  // =============================================
  // Phase 3: Set workflow properties
  // =============================================

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
    try {
      final workflow = await _factory.workflowService.get(workflowId);

      // 1. Connect uploaded files to their TableStep inputs.
      //    FCS zip: RenameRelation → InMemoryRelation with .documentId
      //      (V2: WorkflowRunner.addDocument / createDocumentRelation)
      //    Annotation CSV table: RenameRelation → SimpleRelation(id=schemaId)
      //      (V2: WorkflowRunner.addTableDocument / loadDocumentInMemory)
      for (final step in workflow.steps) {
        if (step is! TableStep) continue;
        if (step.id == _fcsTableStepId && fcsFileDocId.isNotEmpty) {
          step.model.relation = _createDocumentRelation(fcsFileDocId);
          step.state.taskState = DoneState();
        } else if (step.id == _annotationTableStepId && annotationFileDocId.isNotEmpty) {
          step.model.relation = await _createTableRelation(annotationFileDocId);
          step.state.taskState = DoneState();
        }
      }

      // 2. Set algorithmic parameters on DataStep operator properties.
      for (final step in workflow.steps) {
        if (step is! DataStep) continue;
        final props =
            step.model.operatorSettings.operatorRef.propertyValues;
        for (final pv in props) {
          switch (pv.name) {
            case 'k':
              pv.value = phenographK.toString();
            case 'n_neighbors':
              pv.value = umapNNeighbors.toString();
            case 'min_dist':
              pv.value = umapMinDist.toString();
            case 'seed':
            case 'random_seed':
              pv.value = randomSeed.toString();
            case 'max_events':
            case 'max_events_per_file':
              pv.value = maxEventsPerFile.toString();
            case 'channels':
            case 'selected_channels':
              pv.value = selectedChannels.join(',');
          }
        }
      }

      await _factory.workflowService.update(workflow);
    } catch (e) {
      print('Tercen error in setWorkflowProperties: $e');
      rethrow;
    }
  }

  /// Creates a RenameRelation wrapping a SimpleRelation that references an
  /// already-parsed table schema (from CSVTask).  This is how Tercen connects
  /// parsed CSV tables to TableStep inputs — matches webapp_lib
  /// WorkflowRunner.loadDocumentInMemory().
  ///
  /// Unlike [_createDocumentRelation] (which wraps an InMemoryRelation with
  /// `.documentId` for raw file documents), this points directly at the schema
  /// via SimpleRelation.id — the engine reads already-materialized rows.
  Future<RenameRelation> _createTableRelation(String schemaId) async {
    final sch = await _factory.tableSchemaService.get(schemaId);
    final colNames = sch.columns
        .where((c) => c.name != '.ci')
        .map((c) => c.name)
        .toList();

    final rr = RenameRelation();
    rr.inNames.addAll(colNames);
    rr.outNames.addAll(colNames);
    rr.relation = SimpleRelation()..id = sch.id;
    return rr;
  }

  /// Creates a RenameRelation wrapping a 1-row InMemoryRelation that carries
  /// a Tercen file document ID.  This is how Tercen connects uploaded files
  /// to TableStep inputs — matches webapp_lib WorkflowRunner.createDocumentRelation().
  ///
  /// The table has two columns:
  ///   "documentId"  — a unique row-key (opaque to Tercen, just needs to be unique)
  ///   ".documentId" — the actual Tercen FileDocument ID the engine will load
  RenameRelation _createDocumentRelation(String documentId) {
    final rowKey = _newId();
    final relId = _newId();

    final col1 = Column()
      ..name = 'documentId'
      ..type = 'string'
      ..id = 'documentId'
      ..nRows = 1
      ..size = -1
      ..values = [rowKey];

    final col2 = Column()
      ..name = '.documentId'
      ..type = 'string'
      ..id = '.documentId'
      ..nRows = 1
      ..size = -1
      ..values = [documentId];

    final tbl = Table()..nRows = 1;
    tbl.columns.addAll([col1, col2]);

    final inMemRel = InMemoryRelation()
      ..id = relId
      ..inMemoryTable = tbl;

    final rr = RenameRelation()
      ..id = 'rename_$relId'
      ..relation = inMemRel;
    rr.inNames.addAll(['documentId', '.documentId']);
    rr.outNames.addAll(['documentId', '.documentId']);
    return rr;
  }

  /// Generates a unique opaque ID (hex timestamp + random suffix).
  String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    final r = math.Random().nextInt(0x3fffffff);
    return '${t.toRadixString(16)}${r.toRadixString(16).padLeft(8, '0')}';
  }

  // =============================================
  // Phase 3: Workflow execution
  // =============================================

  @override
  Future<void> runWorkflow(
    String workflowId, {
    required OnProgressCallback onProgress,
    required OnLogCallback onLog,
    required OnCompleteCallback onComplete,
    required OnErrorCallback onError,
  }) async {
    try {
      final workflow = await _factory.workflowService.get(workflowId);

      // state = InitState() and owner are required — V2 sets both explicitly.
      final task = RunWorkflowTask()
        ..state = InitState()
        ..owner = workflow.acl.owner
        ..projectId = _projectId
        ..workflowId = workflow.id
        ..workflowRev = workflow.rev;

      // Run all executable steps EXCEPT TableSteps (which are input sources
      // with file connections that must NOT be reset).  This includes both
      // DataSteps (computation) AND ViewSteps (visualisation).  ViewStep
      // extends Step directly — it is NOT a subclass of DataStep — so a
      // plain `is DataStep` check silently skips all visualisation steps.
      for (final step in workflow.steps) {
        if (step is! TableStep) {
          task.stepsToRun.add(step.id);
        }
      }
      // stepsToReset left empty — matches V2 behaviour

      final created =
          await _factory.taskService.create(task) as RunWorkflowTask;
      _runningTaskId = created.id;

      // V2 pattern: subscribe to event stream BEFORE starting the task
      // to avoid missing early events.
      final eventStream =
          _factory.eventService.listenTaskChannel(created.id, false);
      await _factory.taskService.runTask(created.id);

      // Track overall workflow progress by counting completed sub-steps.
      // TaskProgressEvent.actual/total are per-operator values (e.g. "3
      // of 3 files"), NOT overall. We count sub-task DoneState events
      // instead, which gives real step-level progress.
      final totalDataSteps = task.stepsToRun.length;
      int completedStepCount = 0;
      final completedTaskIds = <String>{};
      String currentStepMessage = '';

      // Report initial progress (0 of N)
      onProgress('Starting...', 0, totalDataSteps);

      // Phase 1: Listen to progress events via WebSocket.
      // Only break when the RunWorkflowTask itself reaches a final state
      // (not when a sub-step does). V2 checks evt.taskId == workflowTask.id.
      await for (final event in eventStream) {
        if (event is TaskProgressEvent) {
          // Per-operator message (e.g. "Downloading packages...")
          currentStepMessage = event.message;
          onProgress(currentStepMessage, completedStepCount, totalDataSteps);
        } else if (event is TaskLogEvent) {
          onLog(event.message);
        } else if (event is TaskStateEvent) {
          // RunWorkflowTask itself reached final state → done
          if (event.taskId == created.id && event.state.isFinal) {
            break;
          }
          // A sub-step completed → increment overall progress.
          // Cap at totalDataSteps because the event stream may deliver
          // DoneState events for sub-tasks beyond the workflow step count
          // (e.g. internal orchestration tasks).
          if (event.taskId != created.id &&
              event.state is DoneState &&
              completedTaskIds.add(event.taskId)) {
            completedStepCount++;
            final reported = completedStepCount > totalDataSteps
                ? totalDataSteps
                : completedStepCount;
            onProgress(currentStepMessage, reported, totalDataSteps);
          }
        }
      }

      // Phase 2: After stream ends, verify ALL workflow steps completed.
      // V2 checks every step with throwIfNotDone() after the event loop.
      // The RunWorkflowTask may report Done before all operators finish,
      // or the stream may close early (WebSocket disconnect).
      _runningTaskId = null;
      final finalWf = await _factory.workflowService.get(workflowId);

      for (final step in finalWf.steps) {
        if (step.state.taskState is FailedState) {
          final failed = step.state.taskState as FailedState;
          onError(failed.error,
              'Step "${step.name}" failed: ${failed.reason}');
          return;
        }
      }

      onComplete(workflowId);
    } catch (e) {
      _runningTaskId = null;
      print('Tercen error in runWorkflow: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  @override
  Future<void> cancelRun(String taskId) async {
    try {
      final id = taskId.isNotEmpty ? taskId : _runningTaskId;
      if (id != null) {
        await _factory.taskService.cancelTask(id);
        _runningTaskId = null;
      }
    } catch (e) {
      print('Tercen error in cancelRun: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteWorkflow(String workflowId) async {
    try {
      final wf = await _factory.workflowService.get(workflowId);
      await _factory.workflowService.delete(wf.id, wf.rev);
    } catch (e) {
      print('Tercen error in deleteWorkflow: $e');
      rethrow;
    }
  }

  @override
  Future<int> getWorkflowStepCount(String workflowId) async {
    try {
      final wf = await _factory.workflowService.get(workflowId);
      return wf.steps.length;
    } catch (e) {
      return 0;
    }
  }

  // =============================================
  // Phase 3: Single-step execution
  // =============================================

  @override
  Future<void> runWorkflowStep(String workflowId, String stepName) async {
    try {
      final workflow = await _factory.workflowService.get(workflowId);

      // Find the step by name
      String? stepId;
      for (final step in workflow.steps) {
        if (step.name == stepName) {
          stepId = step.id;
          break;
        }
      }
      if (stepId == null) {
        throw StateError('Step "$stepName" not found in workflow $workflowId');
      }

      // state = InitState() and owner are required — V2 sets both explicitly.
      final task = RunWorkflowTask()
        ..state = InitState()
        ..owner = workflow.acl.owner
        ..projectId = _projectId
        ..workflowId = workflow.id
        ..workflowRev = workflow.rev;

      // Reset and run only this step
      task.stepsToRun.add(stepId);
      task.stepsToReset.add(stepId);

      final created =
          await _factory.taskService.create(task) as RunWorkflowTask;
      _runningTaskId = created.id;
      await _factory.taskService.runTask(created.id);

      await for (final event
          in _factory.eventService.listenTaskChannel(created.id, true)) {
        if (event is TaskStateEvent) {
          if (event.state is DoneState) {
            _runningTaskId = null;
            break;
          } else if (event.state is FailedState) {
            _runningTaskId = null;
            final failed = event.state as FailedState;
            throw Exception(
                'Step "$stepName" failed: ${failed.error}: ${failed.reason}');
          } else if (event.state is CanceledState) {
            _runningTaskId = null;
            throw Exception('Step "$stepName" was canceled');
          }
        }
      }
    } catch (e) {
      _runningTaskId = null;
      print('Tercen error in runWorkflowStep($stepName): $e');
      rethrow;
    }
  }

  @override
  Future<List<FcsChannel>> getChannelsFromWorkflow(String workflowId) async {
    final wf = await _factory.workflowService.get(workflowId);
    return _readChannelReference(wf);
  }

  @override
  Future<int> getMaxEventsPerFile(String workflowId) async {
    final wf = await _factory.workflowService.get(workflowId);
    return _readMaxEventsPerFile(wf);
  }

  /// Read the maximum event count across FCS files from the "Observations"
  /// schema of the "Read FCS" step output. The Observations relation has one
  /// row per event with a `filename` column.
  Future<int> _readMaxEventsPerFile(Workflow wf) async {
    DataStep? readFcsStep;
    for (final step in wf.steps) {
      if (step is DataStep && step.name == 'Read FCS') {
        readFcsStep = step;
        break;
      }
    }
    if (readFcsStep == null || readFcsStep.state.taskState is! DoneState) {
      return 0;
    }

    final relations = _getSimpleRelations(readFcsStep.computedRelation);
    if (relations.isEmpty) return 0;

    final schemaIds = relations.map((r) => r.id).toList();
    final schemas = await _factory.tableSchemaService.list(schemaIds);

    // Find the "Observations" schema (one row per event, has filename column)
    Schema? obsSchema;
    for (final sch in schemas) {
      if (sch.name == 'Observations') {
        obsSchema = sch;
        break;
      }
    }
    if (obsSchema == null || obsSchema.nRows == 0) return 0;

    // Find the filename column
    final filenameCol = obsSchema.columns
        .where((c) => c.name.contains('filename'))
        .firstOrNull;
    if (filenameCol == null) return 0;

    // Read all filename values and count per file
    final table = await _factory.tableSchemaService.select(
      obsSchema.id,
      [filenameCol.name],
      0,
      obsSchema.nRows,
    );

    final filenames = _getColumnValues<String>(table, filenameCol.name);
    if (filenames == null || filenames.isEmpty) return 0;

    final counts = <String, int>{};
    for (final fn in filenames) {
      counts[fn] = (counts[fn] ?? 0) + 1;
    }
    return counts.values.reduce((a, b) => a > b ? a : b);
  }

  // =============================================
  // Step output reading helpers
  // =============================================

  /// Read output data from a named step in the workflow.
  Future<Table?> _readStepOutput(Workflow wf, String stepName) async {
    DataStep? targetStep;
    for (final step in wf.steps) {
      if (step is DataStep && step.name == stepName) {
        targetStep = step;
        break;
      }
    }
    if (targetStep == null) return null;

    // Only read from completed steps
    if (targetStep.state.taskState is! DoneState) return null;

    final relations = _getSimpleRelations(targetStep.computedRelation);
    if (relations.isEmpty) return null;

    final schemaIds = relations.map((r) => r.id).toList();
    final schemas = await _factory.tableSchemaService.list(schemaIds);

    // Find first schema with data
    for (final schema in schemas) {
      if (schema.nRows > 0) {
        return await _factory.tableSchemaService.select(
          schema.id,
          schema.columns.map((c) => c.name).toList(),
          0,
          schema.nRows,
        );
      }
    }
    return null;
  }

  /// Extract typed column values from a Table.
  List<T>? _getColumnValues<T>(Table table, String columnName) {
    for (final col in table.columns) {
      // Match by exact name or strip namespace prefix
      final name = col.name.contains('.')
          ? col.name.split('.').last
          : col.name;
      if (name == columnName) {
        final values = col.values;
        if (values is List) {
          return values.cast<T>();
        }
      }
    }
    return null;
  }

  /// Walk the relation tree and extract leaf relations that carry schema IDs
  /// (SimpleRelation, ReferenceRelation, InMemoryRelation).
  List<Relation> _getSimpleRelations(Relation relation) {
    final result = <Relation>[];
    void walk(Relation? r) {
      if (r == null) return;
      // Leaf nodes — carry a schema/table ID
      if (r is SimpleRelation || r is ReferenceRelation || r is InMemoryRelation) {
        result.add(r);
      }
      // Multi-child containers
      else if (r is CompositeRelation) {
        walk(r.mainRelation);
        for (final j in r.joinOperators) {
          walk(j.rightRelation);
        }
      } else if (r is UnionRelation) {
        for (final child in r.relations) {
          walk(child);
        }
      }
      // Single-child wrappers
      else if (r is WhereRelation) {
        walk(r.relation);
      } else if (r is RenameRelation) {
        walk(r.relation);
      } else if (r is GatherRelation) {
        walk(r.relation);
      } else if (r is DistinctRelation) {
        walk(r.relation);
      } else if (r is GroupByRelation) {
        walk(r.relation);
      } else if (r is RangeRelation) {
        walk(r.relation);
      } else if (r is PairwiseRelation) {
        walk(r.relation);
      }
    }
    walk(relation);
    return result;
  }

  // =============================================
  // Diagnostics
  // =============================================

  Future<void> _printDiagnosticReport() async {
    print('=== TERCEN DIAGNOSTIC REPORT (Flow E) ===');
    print('ProjectId: $_projectId');

    try {
      final project = await _factory.projectService.get(_projectId);
      print('Project: ${project.name} (owner: ${project.acl.owner})');
    } catch (e) {
      print('Project fetch ERROR: $e');
    }

    try {
      final allDocs = await _factory.projectDocumentService
          .findProjectObjectsByLastModifiedDate(
        startKey: [_projectId, ''],
        endKey: [_projectId, '\uf000'],
        useFactory: true,
      );
      final workflows = allDocs.whereType<Workflow>().toList();
      print('Workflows in project: ${workflows.length}');
      for (final w in workflows) {
        print('  - ${w.name} (${w.id})');
      }
    } catch (e) {
      print('Workflow list ERROR: $e');
    }

    print('=== END REPORT ===');
  }
}
