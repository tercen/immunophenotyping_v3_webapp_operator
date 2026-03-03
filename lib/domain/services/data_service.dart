import 'dart:typed_data';
import '../../presentation/providers/app_state_provider.dart';
import '../models/fcs_channel.dart';
import '../models/run_result.dart';

/// Callback types for workflow execution progress monitoring.
typedef OnProgressCallback = void Function(
    String message, int actual, int total);
typedef OnLogCallback = void Function(String message);
typedef OnStepStateCallback = void Function(String stepName, String state);
typedef OnCompleteCallback = void Function(String workflowId);
typedef OnErrorCallback = void Function(String error, String reason);

/// Type 3 data service interface for the immunophenotyping app.
///
/// Stateful service that tracks input stages and provides run history/results.
/// Phase 2: mock implementation loads from assets.
/// Phase 3: real implementation connects to Tercen APIs.
abstract class DataService {
  /// Get the run history (pre-populated in mock, from project in real).
  Future<List<RunEntry>> getRunHistory();

  /// Get result data for a specific run (by workflow ID in real mode).
  Future<RunResult> getResults(String runId);

  /// Get the list of channels from FCS data.
  Future<List<FcsChannel>> getChannels();

  /// Get input configuration for the given stage.
  Future<Map<String, dynamic>> getInputConfig(int stage);

  /// Submit input settings. Returns the next stage index, or -1 if ready to run.
  Future<int> submitInput(Map<String, dynamic> settings);

  // --- Phase 3: Workflow execution methods ---

  /// Get available teams for the current user. Returns list of team names.
  Future<List<String>> getTeams() async => [];

  /// Create a Tercen project in the given team.
  /// Returns the project ID.
  Future<String> createProject(String teamName, String projectName) async =>
      'mock-project';

  /// Upload a file (FCS zip or annotation CSV) to the project.
  /// Returns a file document ID for referencing in the workflow.
  Future<String> uploadFile(
          String filename, Uint8List bytes, String projectId) async =>
      'mock-file-id';

  /// Upload a CSV file and parse it into a Tercen table via CSVTask.
  /// Returns a schema ID (not a file document ID) for use with TableSteps.
  Future<String> uploadCsvAsTable(
          String filename, Uint8List bytes, String projectId) async =>
      'mock-schema-id';

  /// Clone the workflow template into the project for a new run.
  /// Returns the cloned workflow ID.
  Future<String> cloneWorkflowTemplate(String projectId) async =>
      'mock-workflow';

  /// Set operator properties on the cloned workflow before execution.
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
  }) async {}

  /// Run the workflow and stream progress events.
  /// Calls the callbacks as events arrive. Returns when the run completes
  /// or fails.
  Future<void> runWorkflow(
    String workflowId, {
    required OnProgressCallback onProgress,
    required OnLogCallback onLog,
    required OnCompleteCallback onComplete,
    required OnErrorCallback onError,
  }) async {}

  /// Cancel a running workflow task.
  Future<void> cancelRun(String taskId) async {}

  /// Delete a cloned workflow (and its results) from the project.
  Future<void> deleteWorkflow(String workflowId) async {}

  /// Get the total number of steps in the workflow template.
  Future<int> getWorkflowStepCount(String workflowId) async => 0;

  /// Run a single named step in the workflow.
  /// The step is reset and re-run. Throws on step failure or if step not found.
  Future<void> runWorkflowStep(String workflowId, String stepName) async {}

  /// Read FCS channels from the "Read FCS" step output of a workflow.
  Future<List<FcsChannel>> getChannelsFromWorkflow(String workflowId) async => [];

  /// Read the maximum event count across all FCS files from the "Read FCS"
  /// step output. Returns 0 if not available.
  Future<int> getMaxEventsPerFile(String workflowId) async => 0;
}
