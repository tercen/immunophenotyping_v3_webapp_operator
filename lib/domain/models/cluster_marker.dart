/// A significant cluster-marker enrichment result (p < 0.10).
class ClusterMarker {
  final String cluster;
  final String marker;
  final double enrichmentScore;
  final double pValue;

  const ClusterMarker({
    required this.cluster,
    required this.marker,
    required this.enrichmentScore,
    required this.pValue,
  });
}
