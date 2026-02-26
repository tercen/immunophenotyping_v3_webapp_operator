import 'dart:typed_data';

/// Status of an individual file within an UploadZone.
enum UploadFileStatus {
  /// Currently uploading — progress is between 0.0 and 1.0.
  uploading,

  /// Upload completed successfully.
  success,

  /// Upload failed — can be retried.
  error,
}

/// Represents a single file managed by an UploadZone.
///
/// Immutable value object. The widget creates new instances when
/// status or progress changes.
class UploadFile {
  /// Unique identifier for this file entry.
  final String id;

  /// Display filename (e.g., "sample_data.fcs").
  final String filename;

  /// File size in bytes.
  final int fileSize;

  /// Current upload status.
  final UploadFileStatus status;

  /// Upload progress from 0.0 to 1.0. Only meaningful when status == uploading.
  final double progress;

  /// Error message when status == error.
  final String? errorMessage;

  /// Raw file bytes (populated from browser File API in real mode).
  final Uint8List? bytes;

  const UploadFile({
    required this.id,
    required this.filename,
    required this.fileSize,
    this.status = UploadFileStatus.uploading,
    this.progress = 0.0,
    this.errorMessage,
    this.bytes,
  });

  /// Create a copy with updated fields.
  UploadFile copyWith({
    UploadFileStatus? status,
    double? progress,
    String? errorMessage,
    Uint8List? bytes,
  }) {
    return UploadFile(
      id: id,
      filename: filename,
      fileSize: fileSize,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      bytes: bytes ?? this.bytes,
    );
  }

  /// Formatted file size string (B / KB / MB).
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
