import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/fcs_channel.dart';
import '../../domain/models/run_result.dart';
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
  String _selectedTeam = 'My Team';
  String get selectedTeam => _selectedTeam;
  void setSelectedTeam(String team) {
    _selectedTeam = team;
    notifyListeners();
  }

  String _projectName = 'Flow Immunophenotyping - User - 2026-02-25';
  String get projectName => _projectName;
  void setProjectName(String name) {
    _projectName = name;
    notifyListeners();
  }

  List<String> get availableTeams =>
      ['My Team', 'Lab Alpha', 'Research Group B', 'Demo Team'];

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

  int _maxEventsPerFile = 1000;
  int get maxEventsPerFile => _maxEventsPerFile;
  void setMaxEventsPerFile(int value) {
    _maxEventsPerFile = value;
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
      summary['FCS file'] =
          '$_fcsFilename ($_fcsFileCount files, $_fcsChannelCount ch)';
    }
    if (_annotationUploaded) {
      summary['Annotation'] =
          '$_annotationFilename ($_annotationSampleCount samples)';
    }
    if (_selectedChannels.isNotEmpty && _currentStage >= 3) {
      summary['Channels'] =
          '$selectedChannelCount of ${_allChannels.length} selected';
    }
    if (_currentStage >= 3) {
      summary['Downsampling'] = '$_maxEventsPerFile events/file';
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
  // Input completion per stage
  // =============================================
  bool get isStageComplete {
    switch (_currentStage) {
      case 0:
        return _selectedTeam.isNotEmpty && _projectName.isNotEmpty;
      case 1:
        return _fcsUploaded;
      case 2:
        return _annotationUploaded && _annotationCrossCheckPassed;
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

  /// Start a run. In mock mode, transitions immediately to Display.
  void startRun() {
    final runId = 'run_${DateTime.now().millisecondsSinceEpoch}';
    final name = _runName.isNotEmpty ? _runName : defaultRunName;
    final entry = RunEntry(
      id: runId,
      name: name,
      timestamp: DateTime.now(),
      status: 'complete',
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

    // Load results asynchronously
    _loadResults(runId);
    notifyListeners();
  }

  Future<void> _loadResults(String runId) async {
    try {
      // For mock new runs, use run_1 results (complete)
      final resultId =
          (runId == 'run_1' || runId == 'run_2' || runId == 'run_3')
              ? runId
              : 'run_1';
      _currentResult = await _dataService.getResults(resultId);
      notifyListeners();
    } catch (_) {
      // Silently handle errors in mock mode
    }
  }

  /// Stop the current run.
  void stopRun() {
    _appState = AppState.waiting;
    // Return to Stage 3 per spec
    _contentMode = ContentMode.input;
    navigateToStage(3);
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

    // Reset channel selection to defaults
    for (final ch in _allChannels) {
      _selectedChannels[ch.name] = !ch.isQc;
    }

    // Reset analysis parameters to defaults
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

    // Pre-fill FCS upload
    _fcsFilename = s['fcsFilename'] as String?;
    _fcsFileCount = s['fcsFileCount'] as int? ?? 0;
    _fcsChannelCount = s['totalChannels'] as int? ?? 0;
    _fcsTotalEvents = 4082;
    _fcsFileSize = 2457600;
    _fcsUploaded = _fcsFilename != null && _fcsFilename!.isNotEmpty;

    // Pre-fill annotation upload
    _annotationFilename = s['annotationFilename'] as String?;
    _annotationSampleCount = s['sampleCount'] as int? ?? 0;
    _annotationConditions =
        (s['conditions'] as List?)?.cast<String>() ?? [];
    _annotationCrossCheckPassed = true;
    _annotationUploaded =
        _annotationFilename != null && _annotationFilename!.isNotEmpty;

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

  /// Delete a run and its results.
  void deleteRun(String runId) {
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
