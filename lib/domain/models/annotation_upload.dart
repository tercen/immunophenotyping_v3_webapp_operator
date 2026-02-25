/// Represents the result of uploading and validating an annotation CSV file.
class AnnotationUpload {
  /// Original filename of the CSV.
  final String filename;

  /// Number of sample rows in the annotation.
  final int sampleCount;

  /// List of unique conditions found.
  final List<String> conditions;

  /// Whether cross-validation against FCS filenames passed.
  final bool crossCheckPassed;

  const AnnotationUpload({
    required this.filename,
    required this.sampleCount,
    required this.conditions,
    required this.crossCheckPassed,
  });
}
