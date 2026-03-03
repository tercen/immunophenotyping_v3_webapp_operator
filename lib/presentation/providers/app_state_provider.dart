import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/fcs_channel.dart';
import '../../domain/models/run_result.dart';
import '../../domain/models/upload_file.dart';
import '../../domain/services/data_service.dart';

/// App states -- two hard states.
enum AppState { running, waiting }

/// Content panel modes.
enum ContentMode { input, display }

/// A run history entry.
class RunEntry {
  final String id;
  final String name;
  final DateTime timestamp;
  final String status; // 'complete', 'error', 'stopped'
  final Map<String, dynamic> settings;

  const RunEntry({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.status,
    this.settings = const {},
  });
}

/// Immunophenotyping AppStateProvider -- manages app state, content mode,
/// run history, input stages, and all user-configurable settings.
///
/// 5 Input Stages:
///   0: Project Setup (standalone only)
///   1: Upload FCS Files
///   2: Upload Sample Annotation
///   3: Channel Selection & Downsampling
///   4: Analysis Settings & Run
class AppStateProvider extends ChangeNotifier {
  final DataService _dataService;

  AppStateProvider({DataService? dataService})
      : _dataService = dataService ?? serviceLocator<DataService>();

  // --- App state machine ---
  AppState _appState = AppState.waiting;
  AppState get appState => _appState;
  bool get isRunning => _appState == AppState.running;

  ContentMode _contentMode = ContentMode.input;
  ContentMode get contentMode => _contentMode;

  // --- Data loading ---
  bool _isLoading = false;
  String? _error;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load teams for project setup (Stage 0).
      // Isolated so a failure here does not block history/channel loading.
      try {
        final teams = await _dataService.getTeams();
        _availableTeams = teams.isNotEmpty ? teams : _availableTeams;
      } catch (e) {
        print('Failed to load teams (non-fatal): $e');
        // Keep whatever fallback _availableTeams already holds.
      }
      if (_availableTeams.isEmpty) _availableTeams = ['My Team'];
      _selectedTeam = _availableTeams.first;
      _projectName = _generateDefaultProjectName(_selectedTeam);

      final history = await _dataService.getRunHistory();
      _runHistory = history;
      final channels = await _dataService.getChannels();
      _allChannels = channels;
      // Initialize channel selection: all non-QC channels selected
      _selectedChannels = {
        for (final ch in channels)
          if (!ch.isQc) ch.name: true else ch.name: false,
      };
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Header Panel config ---
  String _headerHeading = 'Create Project';
  String get headerHeading => _headerHeading;

  String _headerActionLabel = 'Create Project';
  String get headerActionLabel => _headerActionLabel;

  void setHeaderConfig(
      {required String heading, String actionLabel = 'Continue'}) {
    _headerHeading = heading;
    _headerActionLabel = actionLabel;
    notifyListeners();
  }

  // --- Current input stage ---
  int _currentStage = 0;
  int get currentStage => _currentStage;

  // Stage headings and action labels per spec Section 4.3
  static const _stageConfig = [
    {'heading': 'Create Project', 'action': 'Create Project'},
    {'heading': 'Upload FCS Files', 'action': 'Continue'},
    {'heading': 'Upload Sample Annotation', 'action': 'Continue'},
    {'heading': 'Select Channels', 'action': 'Continue'},
    {'heading': 'Analysis Settings', 'action': 'Run'},
  ];

  // =============================================
  // Stage 0: Project Setup
  // =============================================
  String _selectedTeam = '';
  String get selectedTeam => _selectedTeam;
  void setSelectedTeam(String team) {
    _selectedTeam = team;
    notifyListeners();
  }

  String _projectName = '';
  String get projectName => _projectName;
  void setProjectName(String name) {
    _projectName = name;
    notifyListeners();
  }

  String? _projectCreationError;
  String? get projectCreationError => _projectCreationError;
  void clearProjectCreationError() {
    _projectCreationError = null;
    notifyListeners();
  }

  String? _advanceError;
  String? get advanceError => _advanceError;
  void clearAdvanceError() {
    _advanceError = null;
    notifyListeners();
  }

  /// Generates the default project name: Flow Immunophenotyping - YYYY-MM-DD_HH_mm_SS-username
  String _generateDefaultProjectName(String username) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
    return 'Flow Immunophenotyping - ${date}_$time-$username';
  }

  List<String> _availableTeams = [];
  List<String> get availableTeams => _availableTeams;

  // =============================================
  // Stage 1: Upload FCS Files
  // =============================================
  String? _fcsFilename;
  String? get fcsFilename => _fcsFilename;
  int _fcsFileSize = 0;
  int get fcsFileSize => _fcsFileSize;
  int _fcsFileCount = 0;
  int get fcsFileCount => _fcsFileCount;
  int _fcsChannelCount = 0;
  int get fcsChannelCount => _fcsChannelCount;
  int _fcsTotalEvents = 0;
  int get fcsTotalEvents => _fcsTotalEvents;
  bool _fcsUploaded = false;
  bool get fcsUploaded => _fcsUploaded;

  /// Simulate FCS file upload with mock data.
  void simulateFcsUpload() {
    _fcsFilename = 'omip69_1k_donor.zip';
    _fcsFileSize = 2457600; // ~2.3 MB
    _fcsFileCount = 4;
    _fcsChannelCount = 38;
    _fcsTotalEvents = 4082;
    _fcsUploaded = true;
    notifyListeners();
  }

  void clearFcsUpload() {
    _fcsFilename = null;
    _fcsFileSize = 0;
    _fcsFileCount = 0;
    _fcsChannelCount = 0;
    _fcsTotalEvents = 0;
    _fcsUploaded = false;
    _fcsBytes = null;
    _fcsUploadFilename = null;
    // Clear preflight state — FCS file removed, must re-run Stage 1 advance
    _clonedWorkflowId = null;
    _fcsFileDocId = null;
    _annotationFileDocId = null;
    _allChannels = [];
    _selectedChannels = {};
    notifyListeners();
  }

  // =============================================
  // Stage 2: Upload Sample Annotation
  // =============================================
  String? _annotationFilename;
  String? get annotationFilename => _annotationFilename;
  int _annotationSampleCount = 0;
  int get annotationSampleCount => _annotationSampleCount;
  List<String> _annotationConditions = [];
  List<String> get annotationConditions => _annotationConditions;
  bool _annotationCrossCheckPassed = false;
  bool get annotationCrossCheckPassed => _annotationCrossCheckPassed;
  bool _annotationUploaded = false;
  bool get annotationUploaded => _annotationUploaded;

  /// Simulate annotation CSV upload with mock data.
  void simulateAnnotationUpload() {
    _annotationFilename = 'Sample_annotation.csv';
    _annotationSampleCount = 4;
    _annotationConditions = ['Donor1', 'Donor2', 'Donor3', 'Donor4'];
    _annotationCrossCheckPassed = true;
    _annotationUploaded = true;
    notifyListeners();
  }

  void clearAnnotationUpload() {
    _annotationFilename = null;
    _annotationSampleCount = 0;
    _annotationConditions = [];
    _annotationCrossCheckPassed = false;
    _annotationUploaded = false;
    _annotationBytes = null;
    _annotationUploadFilename = null;
    _annotationFileDocId = null;
    notifyListeners();
  }

  // =============================================
  // Raw file bytes for Tercen upload
  // =============================================
  Uint8List? _fcsBytes;
  Uint8List? get fcsBytes => _fcsBytes;
  String? _fcsUploadFilename;

  Uint8List? _annotationBytes;
  Uint8List? get annotationBytes => _annotationBytes;
  String? _annotationUploadFilename;

  // =============================================
  // Tercen upload artefacts (set during Stage 1/2 advance)
  // =============================================
  String? _clonedWorkflowId;
  String? _fcsFileDocId;
  String? _annotationFileDocId;

  /// Bridge: update FCS upload state from UploadZone file list.
  void updateFcsUploadFromFiles(List<UploadFile> files) {
    final successFiles =
        files.where((f) => f.status == UploadFileStatus.success).toList();

    if (successFiles.isEmpty) {
      if (_fcsUploaded) clearFcsUpload();
      return;
    }

    _fcsFilename = successFiles.length == 1
        ? successFiles.first.filename
        : '${successFiles.length} files';
    _fcsFileSize = successFiles.fold(0, (sum, f) => sum + f.fileSize);
    _fcsChannelCount = 0; // populated after "Read FCS" step runs
    _fcsTotalEvents = 0;  // populated after "Read FCS" step runs
    _fcsUploaded = true;

    // Capture bytes for Tercen upload
    final firstWithBytes =
        successFiles.where((f) => f.bytes != null).firstOrNull;
    if (firstWithBytes != null) {
      _fcsBytes = firstWithBytes.bytes;
      _fcsUploadFilename = firstWithBytes.filename;
    }

    // Count files: if a single zip was uploaded, count entries inside it;
    // otherwise the count is the number of individual files selected.
    if (successFiles.length == 1 &&
        (successFiles.first.filename.toLowerCase().endsWith('.zip')) &&
        _fcsBytes != null) {
      final zipCount = _countZipEntries(_fcsBytes!);
      _fcsFileCount = zipCount > 0 ? zipCount : 1;
    } else {
      _fcsFileCount = successFiles.length;
    }
    notifyListeners();
  }

  /// Bridge: update annotation upload state from UploadZone file list.
  /// Bytes are stored for Tercen upload; metadata is populated after the
  /// "Input Annotation" workflow step runs (in _advanceFromStage2).
  void updateAnnotationUploadFromFiles(List<UploadFile> files) {
    final successFiles =
        files.where((f) => f.status == UploadFileStatus.success).toList();

    if (successFiles.isEmpty) {
      if (_annotationUploaded) clearAnnotationUpload();
      return;
    }

    _annotationFilename = successFiles.first.filename;
    _annotationUploaded = true;

    // Capture bytes for Tercen upload
    final firstWithBytes =
        successFiles.where((f) => f.bytes != null).firstOrNull;
    if (firstWithBytes != null) {
      _annotationBytes = firstWithBytes.bytes;
      _annotationUploadFilename = firstWithBytes.filename;
    }
    notifyListeners();
  }

  // =============================================
  // Stage 3: Channel Selection & Downsampling
  // =============================================
  List<FcsChannel> _allChannels = [];
  List<FcsChannel> get allChannels => _allChannels;

  Map<String, bool> _selectedChannels = {};
  Map<String, bool> get selectedChannels => Map.unmodifiable(_selectedChannels);

  int get selectedChannelCount =>
      _selectedChannels.values.where((v) => v).length;

  void setChannelSelected(String channelName, bool selected) {
    _selectedChannels[channelName] = selected;
    notifyListeners();
  }

  void selectAllChannels() {
    for (final key in _selectedChannels.keys) {
      _selectedChannels[key] = true;
    }
    notifyListeners();
  }

  void deselectAllChannels() {
    for (final key in _selectedChannels.keys) {
      _selectedChannels[key] = false;
    }
    notifyListeners();
  }

  int _minEventsPerFile = 400;
  int get minEventsPerFile => _minEventsPerFile;
  void setMinEventsPerFile(int value) {
    _minEventsPerFile = value;
    notifyListeners();
  }

  int _maxEventsPerFile = 1000;
  int get maxEventsPerFile => _maxEventsPerFile;
  void setMaxEventsPerFile(int value) {
    _maxEventsPerFile = value;
    notifyListeners();
  }

  void setEventsPerFileRange(int min, int max) {
    _minEventsPerFile = min;
    _maxEventsPerFile = max;
    notifyListeners();
  }

  // Max possible events (from uploaded data)
  int get maxPossibleEvents =>
      _fcsTotalEvents > 0
          ? (_fcsTotalEvents ~/ (_fcsFileCount > 0 ? _fcsFileCount : 1))
              .clamp(400, 10000)
          : 1000;

  // =============================================
  // Stage 4: Analysis Settings & Run
  // =============================================
  String _runName = '';
  String get runName => _runName;
  void setRunName(String name) {
    _runName = name;
    notifyListeners();
  }

  int _phenographK = 30;
  int get phenographK => _phenographK;
  void setPhenographK(int k) {
    _phenographK = k;
    notifyListeners();
  }

  int _umapNNeighbors = 15;
  int get umapNNeighbors => _umapNNeighbors;
  void setUmapNNeighbors(int n) {
    _umapNNeighbors = n;
    notifyListeners();
  }

  double _umapMinDist = 0.5;
  double get umapMinDist => _umapMinDist;
  void setUmapMinDist(double d) {
    _umapMinDist = d;
    notifyListeners();
  }

  int _randomSeed = 42;
  int get randomSeed => _randomSeed;
  void setRandomSeed(int seed) {
    _randomSeed = seed;
    notifyListeners();
  }

  String get defaultRunName {
    final now = DateTime.now();
    return 'Run - ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // =============================================
  // Current run settings (read-only summary)
  // =============================================
  Map<String, String> get currentRunSummary {
    final summary = <String, String>{};

    if (_fcsUploaded) {
      final fileWord = _fcsFileCount == 1 ? 'file' : 'files';
      final chPart = _fcsChannelCount > 0 ? ', $_fcsChannelCount ch' : '';
      summary['FCS file'] = '$_fcsFilename ($_fcsFileCount $fileWord$chPart)';
    }
    if (_annotationUploaded) {
      final samplePart =
          _annotationSampleCount > 0 ? ' ($_annotationSampleCount samples)' : '';
      summary['Annotation'] = '$_annotationFilename$samplePart';
    }
    if (_selectedChannels.isNotEmpty && _currentStage >= 3) {
      summary['Channels'] =
          '$selectedChannelCount of ${_allChannels.length} selected';
    }
    if (_currentStage >= 3) {
      summary['Downsampling'] = '$_minEventsPerFile–$_maxEventsPerFile events/file';
    }
    if (_currentStage >= 4 || _contentMode == ContentMode.display) {
      summary['PhenoGraph k'] = '$_phenographK';
      summary['UMAP n_neighbors'] = '$_umapNNeighbors';
      summary['UMAP min_dist'] = '$_umapMinDist';
      summary['Seed'] = '$_randomSeed';
      if (_runName.isNotEmpty) {
        summary['Run name'] = _runName;
      }
    }

    return summary;
  }

  /// Build settings map for a run from display mode (history entry).
  Map<String, String> settingsSummaryFromRun(RunEntry run) {
    final s = run.settings;
    return {
      'FCS file':
          '${s['fcsFilename'] ?? ''} (${s['fcsFileCount'] ?? 0} files, ${s['totalChannels'] ?? 0} ch)',
      'Annotation':
          '${s['annotationFilename'] ?? ''} (${s['sampleCount'] ?? 0} samples)',
      'Channels':
          '${s['selectedChannelCount'] ?? 0} of ${s['totalChannels'] ?? 0} selected',
      'Downsampling': '${s['maxEventsPerFile'] ?? 0} events/file',
      'PhenoGraph k': '${s['phenographK'] ?? 30}',
      'UMAP n_neighbors': '${s['umapNNeighbors'] ?? 15}',
      'UMAP min_dist': '${s['umapMinDist'] ?? 0.5}',
      'Seed': '${s['randomSeed'] ?? 42}',
      'Run name': '${s['runName'] ?? run.name}',
    };
  }

  // =============================================
  // Run history
  // =============================================
  List<RunEntry> _runHistory = [];
  List<RunEntry> get runHistory => List.unmodifiable(_runHistory);

  String? _selectedRunId;
  String? get selectedRunId => _selectedRunId;

  RunEntry? get selectedRun {
    if (_selectedRunId == null) return null;
    try {
      return _runHistory.firstWhere((r) => r.id == _selectedRunId);
    } catch (_) {
      return null;
    }
  }

  // =============================================
  // Display mode result data
  // =============================================
  RunResult? _currentResult;
  RunResult? get currentResult => _currentResult;

  // =============================================
  // Workflow execution state
  // =============================================
  int _completedSteps = 0;
  int get completedSteps => _completedSteps;
  int _totalSteps = 31;
  int get totalSteps => _totalSteps;
  String _currentRunningStep = '';
  String get currentRunningStep => _currentRunningStep;
  String? _pendingRunId;

  // =============================================
  // Input completion per stage
  // =============================================
  bool get isStageComplete {
    switch (_currentStage) {
      case 0:
        return _selectedTeam.isNotEmpty && _projectName.isNotEmpty;
      case 1:
        return _fcsUploaded;
      case 2:
        // File locally read is sufficient — upload + validation happen on Continue
        return _annotationUploaded;
      case 3:
        return selectedChannelCount > 0;
      case 4:
        return _runName.isNotEmpty;
      default:
        return false;
    }
  }

  bool get isInputComplete => isStageComplete;

  // =============================================
  // Actions
  // =============================================

  /// Navigate to a specific input stage.
  void navigateToStage(int stage) {
    _currentStage = stage.clamp(0, 4);
    final config = _stageConfig[_currentStage];
    _headerHeading = config['heading']!;
    _headerActionLabel = config['action']!;
    notifyListeners();
  }

  /// Advance to the next stage, or start the run if at stage 4.
  void advanceStage() {
    if (_isLoading) return; // Prevent re-entry during async operations

    if (_currentStage == 0) {
      _createProjectAndAdvance();
      return;
    }
    if (_currentStage == 1) {
      // Stage 1 Continue: upload FCS file + clone workflow template.
      // No pipeline steps run yet — just get the file into Tercen.
      _advanceFromStage1();
      return;
    }
    if (_currentStage == 2) {
      // Stage 2 Continue: upload annotation file, then run both preflight
      // steps ("Read FCS" + "Input Annotation") and extract channels.
      _advanceFromStage2();
      return;
    }
    if (_currentStage < 4) {
      navigateToStage(_currentStage + 1);
      // Auto-generate run name default when entering stage 4
      if (_currentStage == 4 && _runName.isEmpty) {
        _runName = defaultRunName;
      }
    } else {
      startRun();
    }
  }

  /// Create a Tercen project, then advance to Stage 1.
  Future<void> _createProjectAndAdvance() async {
    _isLoading = true;
    notifyListeners();
    try {
      final newProjectId =
          await _dataService.createProject(_selectedTeam, _projectName);
      // Update the registered projectId for subsequent operations
      if (serviceLocator.isRegistered<String>(instanceName: 'projectId')) {
        serviceLocator.unregister<String>(instanceName: 'projectId');
      }
      serviceLocator.registerSingleton<String>(
        newProjectId,
        instanceName: 'projectId',
      );
    } catch (e) {
      _projectCreationError = 'Failed to create project: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = false;
    navigateToStage(1);
  }

  /// Stage 1 Continue: upload FCS file to Tercen + clone workflow template.
  /// No pipeline steps run — just get the data into the project so the user
  /// can proceed to provide the annotation file.
  Future<void> _advanceFromStage1() async {
    if (_fcsBytes == null) return;

    _isLoading = true;
    _currentRunningStep = 'Uploading FCS data...';
    _error = null;
    notifyListeners();

    try {
      // 1. Upload FCS file to Tercen
      _fcsFileDocId = await _dataService.uploadFile(
        _fcsUploadFilename ?? _fcsFilename ?? 'fcs_data.zip',
        _fcsBytes!,
        _projectId,
      );

      // 2. Clone workflow template (needed before we can configure inputs)
      _currentRunningStep = 'Cloning workflow template...';
      notifyListeners();
      _clonedWorkflowId = await _dataService.cloneWorkflowTemplate(_projectId);

      _isLoading = false;
      _currentRunningStep = '';
      navigateToStage(2);
    } catch (e) {
      _isLoading = false;
      _currentRunningStep = '';
      _advanceError = 'Failed to upload FCS file: $e';
      notifyListeners();
    }
  }

  /// Stage 2 Continue: upload annotation file → configure workflow with both
  /// file inputs → run preflight steps ("Read FCS" + "Input Annotation") →
  /// extract channels → advance to Stage 3.
  Future<void> _advanceFromStage2() async {
    if (_annotationBytes == null) return;
    if (_clonedWorkflowId == null || _fcsFileDocId == null) {
      _advanceError = 'Workflow not initialised. Please go back to Stage 1.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;

    try {
      // 1. Upload annotation file to Tercen
      _currentRunningStep = 'Uploading annotation...';
      notifyListeners();
      _annotationFileDocId = await _dataService.uploadFile(
        _annotationUploadFilename ?? _annotationFilename ?? 'annotation.csv',
        _annotationBytes!,
        _projectId,
      );

      // 2. Configure workflow with both file inputs
      _currentRunningStep = 'Configuring workflow...';
      notifyListeners();
      await _dataService.setWorkflowProperties(
        _clonedWorkflowId!,
        selectedChannels: const [],
        maxEventsPerFile: _maxEventsPerFile,
        phenographK: _phenographK,
        umapNNeighbors: _umapNNeighbors,
        umapMinDist: _umapMinDist,
        randomSeed: _randomSeed,
        fcsFileDocId: _fcsFileDocId!,
        annotationFileDocId: _annotationFileDocId!,
      );

      // 3. Run "Read FCS" preflight step to extract channel information
      _currentRunningStep = 'Reading FCS metadata...';
      notifyListeners();
      await _dataService.runWorkflowStep(_clonedWorkflowId!, 'Read FCS');

      // 4. Run "Input Annotation" preflight step
      _currentRunningStep = 'Processing annotation...';
      notifyListeners();
      await _dataService.runWorkflowStep(
          _clonedWorkflowId!, 'Input Annotation');
      _annotationCrossCheckPassed = true;

      // 5. Extract channels from the "Read FCS" step output
      _currentRunningStep = 'Extracting channels...';
      notifyListeners();
      final channels =
          await _dataService.getChannelsFromWorkflow(_clonedWorkflowId!);
      if (channels.isNotEmpty) {
        _allChannels = channels;
        _fcsChannelCount = channels.length;
        _selectedChannels = {
          for (final ch in channels)
            if (!ch.isQc) ch.name: true else ch.name: false,
        };
      }

      _isLoading = false;
      _currentRunningStep = '';
      navigateToStage(3);
    } catch (e) {
      _isLoading = false;
      _currentRunningStep = '';
      _advanceError = 'Failed to process uploaded files: $e';
      notifyListeners();
    }
  }

  /// Start a run: configure and execute the full workflow.
  void startRun() {
    final name = _runName.isNotEmpty ? _runName : defaultRunName;

    // Enter running state immediately
    _appState = AppState.running;
    _completedSteps = 0;
    _currentRunningStep = 'Preparing workflow...';
    _headerHeading = name;
    notifyListeners();

    _executeWorkflow(name);
  }

  /// Async workflow execution — configure and run the pre-cloned workflow.
  Future<void> _executeWorkflow(String name) async {
    try {
      // 1. Reuse the pre-cloned workflow (from Stage 1 advance), or clone if needed
      _currentRunningStep = 'Preparing workflow...';
      notifyListeners();
      final workflowId =
          _clonedWorkflowId ?? await _dataService.cloneWorkflowTemplate(_projectId);
      _pendingRunId = workflowId;

      // 2. Get total step count for progress display
      _totalSteps = await _dataService.getWorkflowStepCount(workflowId);
      if (_totalSteps == 0) _totalSteps = 31; // fallback

      // 3. Set all workflow properties (channels, analysis params + uploaded file IDs)
      _currentRunningStep = 'Configuring workflow...';
      notifyListeners();
      final selected = _selectedChannels.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      await _dataService.setWorkflowProperties(
        workflowId,
        selectedChannels: selected,
        maxEventsPerFile: _maxEventsPerFile,
        phenographK: _phenographK,
        umapNNeighbors: _umapNNeighbors,
        umapMinDist: _umapMinDist,
        randomSeed: _randomSeed,
        fcsFileDocId: _fcsFileDocId ?? '',
        annotationFileDocId: _annotationFileDocId ?? '',
      );

      // 4. Run all workflow steps with progress callbacks
      _currentRunningStep = 'Starting execution...';
      notifyListeners();
      await _dataService.runWorkflow(
        workflowId,
        onProgress: (message, actual, total) {
          _completedSteps = actual;
          if (total > 0) _totalSteps = total;
          _currentRunningStep = message;
          notifyListeners();
        },
        onLog: (message) {
          _currentRunningStep = message;
          notifyListeners();
        },
        onComplete: (wfId) {
          _currentRunningStep = '';
          _finishRun(wfId, name, 'complete');
        },
        onError: (error, reason) {
          _currentRunningStep = '';
          _advanceError = reason.isNotEmpty ? '$error: $reason' : error;
          _finishRun(workflowId, name, 'error');
        },
      );
    } catch (e) {
      print('Workflow execution error: $e');
      _advanceError = e.toString();
      if (_pendingRunId != null) {
        _finishRun(_pendingRunId!, name, 'error');
      } else {
        _appState = AppState.waiting;
        _currentRunningStep = '';
        notifyListeners();
      }
    }
  }

  /// The projectId from main.dart, accessed for file uploads.
  String get _projectId =>
      serviceLocator<String>(instanceName: 'projectId');

  /// Finalize a run (complete or stopped) and transition to Display mode.
  void _finishRun(String runId, String name, String status) {
    final entry = RunEntry(
      id: runId,
      name: name,
      timestamp: DateTime.now(),
      status: status,
      settings: {
        'fcsFilename': _fcsFilename ?? '',
        'fcsFileCount': _fcsFileCount,
        'totalChannels': _fcsChannelCount,
        'annotationFilename': _annotationFilename ?? '',
        'sampleCount': _annotationSampleCount,
        'conditions': List<String>.from(_annotationConditions),
        'selectedChannelCount': selectedChannelCount,
        'maxEventsPerFile': _maxEventsPerFile,
        'phenographK': _phenographK,
        'umapNNeighbors': _umapNNeighbors,
        'umapMinDist': _umapMinDist,
        'randomSeed': _randomSeed,
        'runName': name,
      },
    );
    _runHistory.insert(0, entry);
    _selectedRunId = runId;
    _contentMode = ContentMode.display;
    _headerHeading = name;
    _appState = AppState.waiting;
    _pendingRunId = null;

    _loadResults(runId);
    notifyListeners();
  }

  Future<void> _loadResults(String runId) async {
    try {
      _currentResult = await _dataService.getResults(runId);
      notifyListeners();
    } catch (e) {
      print('Error loading results for $runId: $e');
    }
  }

  /// Stop the current run. Cancels the workflow task, saves as 'stopped',
  /// then returns to Input Stage 3.
  void stopRun() {
    // Cancel the real workflow task if running.
    // Pass empty string — the service uses its internal task ID as fallback.
    if (_appState == AppState.running) {
      _dataService.cancelRun('');
    }

    // If a run was in progress, save it as stopped
    if (_pendingRunId != null) {
      final name = _runName.isNotEmpty ? _runName : defaultRunName;
      _finishRun(_pendingRunId!, name, 'stopped');
    }

    // Return to Input Stage 3 per spec
    _appState = AppState.waiting;
    _contentMode = ContentMode.input;
    _currentRunningStep = '';
    _completedSteps = 0;
    navigateToStage(3);
  }

  @override
  void dispose() {
    _dataService.cancelRun('');
    super.dispose();
  }

  /// Reset the app to initial state (Stage 1, clear settings to defaults).
  void resetApp() {
    _appState = AppState.waiting;
    _contentMode = ContentMode.input;

    // Clear uploads
    _fcsFilename = null;
    _fcsFileSize = 0;
    _fcsFileCount = 0;
    _fcsChannelCount = 0;
    _fcsTotalEvents = 0;
    _fcsUploaded = false;

    _annotationFilename = null;
    _annotationSampleCount = 0;
    _annotationConditions = [];
    _annotationCrossCheckPassed = false;
    _annotationUploaded = false;

    // Clear file bytes
    _fcsBytes = null;
    _fcsUploadFilename = null;
    _annotationBytes = null;
    _annotationUploadFilename = null;

    // Clear Tercen upload artefacts
    _clonedWorkflowId = null;
    _fcsFileDocId = null;
    _annotationFileDocId = null;

    // Reset channel selection to defaults
    for (final ch in _allChannels) {
      _selectedChannels[ch.name] = !ch.isQc;
    }

    // Reset analysis parameters to defaults
    _minEventsPerFile = 400;
    _maxEventsPerFile = 1000;
    _phenographK = 30;
    _umapNNeighbors = 15;
    _umapMinDist = 0.5;
    _randomSeed = 42;
    _runName = '';

    // Go to stage 1 (skip project setup for reset)
    _selectedRunId = null;
    _currentResult = null;
    navigateToStage(1);
  }

  /// Select a history entry to view in Display mode.
  void selectHistoryEntry(String runId) {
    _selectedRunId = runId;
    _contentMode = ContentMode.display;
    final run = selectedRun;
    if (run != null) {
      _headerHeading = run.name;
    }
    _appState = AppState.waiting;
    _loadResults(runId);
    notifyListeners();
  }

  /// Initiate a re-run from an existing run. Returns to Input mode
  /// with settings pre-loaded from the selected run.
  void initiateReRun(String runId) {
    final run = _runHistory.firstWhere((r) => r.id == runId);
    final s = run.settings;

    // Pre-fill FCS upload display info (no bytes — user must re-upload)
    _fcsFilename = s['fcsFilename'] as String?;
    _fcsFileCount = s['fcsFileCount'] as int? ?? 0;
    _fcsChannelCount = s['totalChannels'] as int? ?? 0;
    _fcsTotalEvents = 0;
    _fcsFileSize = 0;
    _fcsUploaded = _fcsFilename != null && _fcsFilename!.isNotEmpty;

    // Pre-fill annotation display info (no bytes — user must re-upload)
    _annotationFilename = s['annotationFilename'] as String?;
    _annotationSampleCount = s['sampleCount'] as int? ?? 0;
    _annotationConditions =
        (s['conditions'] as List?)?.cast<String>() ?? [];
    _annotationCrossCheckPassed = true;
    _annotationUploaded =
        _annotationFilename != null && _annotationFilename!.isNotEmpty;

    // Clear bytes and Tercen artefacts — user must re-upload files
    _fcsBytes = null;
    _fcsUploadFilename = null;
    _annotationBytes = null;
    _annotationUploadFilename = null;
    _clonedWorkflowId = null;
    _fcsFileDocId = null;
    _annotationFileDocId = null;

    // Pre-fill channel selection
    final selectedCount = s['selectedChannelCount'] as int? ?? 30;
    int count = 0;
    for (final ch in _allChannels) {
      if (!ch.isQc && count < selectedCount) {
        _selectedChannels[ch.name] = true;
        count++;
      } else {
        _selectedChannels[ch.name] = false;
      }
    }

    // Pre-fill analysis settings
    _maxEventsPerFile = s['maxEventsPerFile'] as int? ?? 1000;
    _phenographK = s['phenographK'] as int? ?? 30;
    _umapNNeighbors = s['umapNNeighbors'] as int? ?? 15;
    _umapMinDist = (s['umapMinDist'] as num?)?.toDouble() ?? 0.5;
    _randomSeed = s['randomSeed'] as int? ?? 42;
    _runName = '';

    _contentMode = ContentMode.input;
    navigateToStage(1);
  }

  /// Count the number of entries in a zip file by reading the End of Central
  /// Directory (EOCD) record at the end of the bytes.  Returns 0 if the bytes
  /// are not a valid zip.
  int _countZipEntries(Uint8List bytes) {
    // EOCD signature: PK\x05\x06.  Search backwards from end (min 22 bytes).
    if (bytes.length < 22) return 0;
    for (int i = bytes.length - 22; i >= 0; i--) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x05 &&
          bytes[i + 3] == 0x06) {
        // Total number of entries is a uint16LE at offset +10 from EOCD start.
        return bytes[i + 10] | (bytes[i + 11] << 8);
      }
    }
    return 0;
  }

  /// Delete a run and its workflow from the project.
  void deleteRun(String runId) {
    // Delete the workflow on Tercen (async, fire-and-forget)
    _dataService.deleteWorkflow(runId);

    _runHistory.removeWhere((r) => r.id == runId);
    if (_selectedRunId == runId) {
      if (_runHistory.isNotEmpty) {
        selectHistoryEntry(_runHistory.first.id);
      } else {
        _selectedRunId = null;
        _currentResult = null;
        _contentMode = ContentMode.input;
        navigateToStage(1);
      }
    } else {
      notifyListeners();
    }
  }
}
