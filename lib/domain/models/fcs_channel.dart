/// Represents a single channel from an FCS file header.
class FcsChannel {
  /// Short name from $PnN (e.g., "BV421-A").
  final String name;

  /// Human-readable description from $PnS (e.g., "CD3").
  final String description;

  /// Whether this is a QC channel (scatter, viability, time).
  final bool isQc;

  const FcsChannel({
    required this.name,
    required this.description,
    this.isQc = false,
  });
}
