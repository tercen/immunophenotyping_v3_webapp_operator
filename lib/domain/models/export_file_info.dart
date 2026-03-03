/// Metadata for a downloadable file produced by a workflow export step.
class ExportFileInfo {
  /// Original filename (e.g. "report.pdf").
  final String filename;

  /// Name of the workflow step that produced this file.
  final String stepName;

  /// MIME content type (e.g. "application/pdf").
  final String contentType;

  /// Schema ID needed to fetch file content on demand.
  final String schemaId;

  const ExportFileInfo({
    required this.filename,
    required this.stepName,
    required this.contentType,
    required this.schemaId,
  });
}
