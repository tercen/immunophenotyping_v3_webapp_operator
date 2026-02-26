import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/models/cluster_marker.dart';
import '../../domain/models/event_count.dart';
import '../../domain/models/fcs_channel.dart';
import '../../domain/models/run_result.dart';
import '../../domain/services/data_service.dart';
import '../../presentation/providers/app_state_provider.dart';

/// Mock Type 3 data service for the immunophenotyping app.
///
/// Loads real data from JSON assets in assets/data/.
/// Pre-populates 3 run history entries (1 complete, 1 stopped, 1 error).
class MockDataService extends DataService {
  List<FcsChannel>? _cachedChannels;
  List<ClusterMarker>? _cachedClusterMarkers;
  List<EventCount>? _cachedEventCounts;

  @override
  Future<List<RunEntry>> getRunHistory() async {
    return [
      RunEntry(
        id: 'run_1',
        name: 'OMIP-069 Full Panel',
        timestamp: DateTime(2026, 2, 24, 14, 32),
        status: 'complete',
        settings: {
          'fcsFilename': 'omip69_1k_donor.zip',
          'fcsFileCount': 4,
          'totalChannels': 38,
          'annotationFilename': 'Sample_annotation.csv',
          'sampleCount': 4,
          'conditions': ['Donor1', 'Donor2', 'Donor3', 'Donor4'],
          'selectedChannelCount': 30,
          'maxEventsPerFile': 1000,
          'phenographK': 30,
          'umapNNeighbors': 15,
          'umapMinDist': 0.5,
          'randomSeed': 42,
          'runName': 'OMIP-069 Full Panel',
        },
      ),
      RunEntry(
        id: 'run_2',
        name: 'High-K Clustering',
        timestamp: DateTime(2026, 2, 24, 16, 5),
        status: 'stopped',
        settings: {
          'fcsFilename': 'omip69_1k_donor.zip',
          'fcsFileCount': 4,
          'totalChannels': 38,
          'annotationFilename': 'Sample_annotation.csv',
          'sampleCount': 4,
          'conditions': ['Donor1', 'Donor2', 'Donor3', 'Donor4'],
          'selectedChannelCount': 30,
          'maxEventsPerFile': 1000,
          'phenographK': 50,
          'umapNNeighbors': 20,
          'umapMinDist': 0.3,
          'randomSeed': 42,
          'runName': 'High-K Clustering',
        },
      ),
      RunEntry(
        id: 'run_3',
        name: 'T-Cell Subset Analysis',
        timestamp: DateTime(2026, 2, 25, 9, 15),
        status: 'error',
        settings: {
          'fcsFilename': 'omip69_1k_donor.zip',
          'fcsFileCount': 4,
          'totalChannels': 38,
          'annotationFilename': 'Sample_annotation.csv',
          'sampleCount': 4,
          'conditions': ['Donor1', 'Donor2', 'Donor3', 'Donor4'],
          'selectedChannelCount': 12,
          'maxEventsPerFile': 500,
          'phenographK': 15,
          'umapNNeighbors': 10,
          'umapMinDist': 0.1,
          'randomSeed': 123,
          'runName': 'T-Cell Subset Analysis',
        },
      ),
    ];
  }

  @override
  Future<RunResult> getResults(String runId) async {
    final channels = await getChannels();
    final clusterMarkers = await _loadClusterMarkers();
    final eventCounts = await _loadEventCounts();

    if (runId == 'run_3') {
      // Error run: partial results
      return RunResult(
        clusterCount: 8,
        clusterMarkers: clusterMarkers.take(15).toList(),
        eventCounts: eventCounts,
        channelReference: channels,
        errorMessage:
            'PhenoGraph operator failed: insufficient events for k=15 with 12 channels. Minimum 100 events per cluster required.',
        failedStep: 'PhenoGraph Clustering',
      );
    }

    if (runId == 'run_2') {
      // Stopped run: partial results from completed steps
      return RunResult(
        clusterCount: 0,
        clusterMarkers: [],
        eventCounts: eventCounts,
        channelReference: channels,
      );
    }

    // Complete run (run_1 or new runs)
    return RunResult(
      clusterCount: 13,
      clusterMarkers: clusterMarkers,
      eventCounts: eventCounts,
      channelReference: channels,
    );
  }

  @override
  Future<List<FcsChannel>> getChannels() async {
    if (_cachedChannels != null) return _cachedChannels!;

    final jsonStr = await rootBundle.loadString('assets/data/channels.json');
    final List<dynamic> jsonList = json.decode(jsonStr);
    _cachedChannels = jsonList
        .map((j) => FcsChannel(
              name: j['name'] as String,
              description: j['description'] as String,
              isQc: j['isQc'] as bool? ?? false,
            ))
        .toList();
    return _cachedChannels!;
  }

  Future<List<ClusterMarker>> _loadClusterMarkers() async {
    if (_cachedClusterMarkers != null) return _cachedClusterMarkers!;

    final jsonStr =
        await rootBundle.loadString('assets/data/cluster_markers.json');
    final List<dynamic> jsonList = json.decode(jsonStr);
    _cachedClusterMarkers = jsonList
        .map((j) => ClusterMarker(
              cluster: j['cluster'] as String,
              marker: j['marker'] as String,
              enrichmentScore: (j['enrichmentScore'] as num).toDouble(),
              pValue: (j['pValue'] as num).toDouble(),
            ))
        .toList();
    return _cachedClusterMarkers!;
  }

  Future<List<EventCount>> _loadEventCounts() async {
    if (_cachedEventCounts != null) return _cachedEventCounts!;

    final jsonStr =
        await rootBundle.loadString('assets/data/event_counts.json');
    final List<dynamic> jsonList = json.decode(jsonStr);
    _cachedEventCounts = jsonList
        .map((j) => EventCount(
              filename: j['filename'] as String,
              rawEvents: j['rawEvents'] as int,
              postFilterEvents: j['postFilterEvents'] as int,
            ))
        .toList();
    return _cachedEventCounts!;
  }

  @override
  Future<Map<String, dynamic>> getInputConfig(int stage) async {
    return {'stage': stage};
  }

  @override
  Future<int> submitInput(Map<String, dynamic> settings) async {
    return -1;
  }
}
