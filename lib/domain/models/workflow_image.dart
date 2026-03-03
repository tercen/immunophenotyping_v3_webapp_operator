import 'dart:typed_data';

/// A single image produced by a workflow step.
class WorkflowImage {
  /// Original filename (e.g. "umap_clusters.png").
  final String filename;

  /// Name of the workflow step that produced this image.
  final String stepName;

  /// Raw image bytes (PNG, JPEG, SVG, etc.).
  final Uint8List data;

  /// MIME content type (e.g. "image/png").
  final String contentType;

  const WorkflowImage({
    required this.filename,
    required this.stepName,
    required this.data,
    required this.contentType,
  });
}
