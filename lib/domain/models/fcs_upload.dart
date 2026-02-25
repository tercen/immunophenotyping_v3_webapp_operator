/// Represents the result of uploading and validating an FCS zip file.
class FcsUpload {
  /// Original filename of the zip.
  final String filename;

  /// Total file size in bytes.
  final int fileSize;

  /// Number of valid FCS files found in the zip.
  final int fileCount;

  /// Number of channels detected across FCS files.
  final int channelCount;

  /// Individual FCS file names within the zip.
  final List<String> fcsFilenames;

  /// Total events across all files.
  final int totalEvents;

  const FcsUpload({
    required this.filename,
    required this.fileSize,
    required this.fileCount,
    required this.channelCount,
    required this.fcsFilenames,
    required this.totalEvents,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
