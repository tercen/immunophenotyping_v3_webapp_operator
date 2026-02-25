import 'cluster_marker.dart';
import 'event_count.dart';
import 'fcs_channel.dart';

/// Complete result data for a single run's display mode.
class RunResult {
  /// Number of clusters found by PhenoGraph.
  final int clusterCount;

  /// Cluster markers table: significant enrichments (p < 0.10).
  final List<ClusterMarker> clusterMarkers;

  /// Event count summary per file.
  final List<EventCount> eventCounts;

  /// Channel reference table (all channels in dataset).
  final List<FcsChannel> channelReference;

  /// Error message if the run failed (null if complete).
  final String? errorMessage;

  /// Name of the step that failed (null if complete).
  final String? failedStep;

  const RunResult({
    required this.clusterCount,
    required this.clusterMarkers,
    required this.eventCounts,
    required this.channelReference,
    this.errorMessage,
    this.failedStep,
  });
}
