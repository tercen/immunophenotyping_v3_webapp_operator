import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/upload_file.dart';

/// Visual state of the drop area, derived from file list + hover.
enum _DropAreaVisualState {
  empty,
  hover,
  active,
}

/// A dashed-border file upload zone — the 12th standard control type.
///
/// Self-contained widget with mock upload simulation:
/// - Click to add files (from a rotating mock pool)
/// - Progress animation per file (~1.5s)
/// - Every 3rd file errors (deterministic for testing)
/// - Retry always succeeds
/// - Remove individual files
/// - Drop area stays visible for multi-file add
///
/// Communicates to parent via [onFilesChanged] and [onAllUploadsComplete].
class UploadZone extends StatefulWidget {
  /// Whether to use dark theme colors.
  final bool isDark;

  /// Label text shown in the drop area.
  final String label;

  /// Optional initial files to pre-populate (e.g., from re-run).
  final List<UploadFile>? initialFiles;

  /// Called whenever the file list changes (add, remove, status change).
  /// Only fires when semantic state changes, not on every progress tick.
  final ValueChanged<List<UploadFile>>? onFilesChanged;

  /// Called when all files reach a terminal state and at least one succeeded.
  final VoidCallback? onAllUploadsComplete;

  /// File type filter for the browser file picker (e.g. '.fcs,.zip').
  final String? accept;

  /// Maximum width constraint.
  final double maxWidth;

  static const double defaultMaxWidth = 480.0;

  const UploadZone({
    super.key,
    required this.isDark,
    this.label = 'Drag & Drop or Click to Browse',
    this.initialFiles,
    this.onFilesChanged,
    this.onAllUploadsComplete,
    this.accept,
    this.maxWidth = defaultMaxWidth,
  });

  @override
  State<UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<UploadZone> {
  List<UploadFile> _files = [];
  bool _hovering = false;
  bool _dragging = false;
  int _dragCounter = 0;
  final Map<String, Timer> _uploadTimers = {};
  final List<StreamSubscription> _dragSubscriptions = [];
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      _files = List.from(widget.initialFiles!);
    }
    _setupDragListeners();
  }

  void _setupDragListeners() {
    final body = web.document.body!;

    body.addEventListener(
      'dragenter',
      ((web.DragEvent event) {
        event.preventDefault();
        _dragCounter++;
        if (!_dragging) setState(() => _dragging = true);
      }).toJS,
    );

    body.addEventListener(
      'dragover',
      ((web.DragEvent event) {
        event.preventDefault();
      }).toJS,
    );

    body.addEventListener(
      'dragleave',
      ((web.DragEvent event) {
        _dragCounter--;
        if (_dragCounter <= 0) {
          _dragCounter = 0;
          if (_dragging) setState(() => _dragging = false);
        }
      }).toJS,
    );

    body.addEventListener(
      'drop',
      ((web.DragEvent event) {
        event.preventDefault();
        _dragCounter = 0;
        setState(() => _dragging = false);
        final files = event.dataTransfer?.files;
        if (files != null) {
          for (int i = 0; i < files.length; i++) {
            _readBrowserFile(files.item(i)!);
          }
        }
      }).toJS,
    );
  }

  @override
  void dispose() {
    for (final sub in _dragSubscriptions) {
      sub.cancel();
    }
    for (final timer in _uploadTimers.values) {
      timer.cancel();
    }
    _uploadTimers.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // State computation
  // ---------------------------------------------------------------------------

  _DropAreaVisualState get _dropAreaState {
    if (_hovering || _dragging) return _DropAreaVisualState.hover;
    if (_files.isNotEmpty) return _DropAreaVisualState.active;
    return _DropAreaVisualState.empty;
  }

  // ---------------------------------------------------------------------------
  // File reading (browser File API)
  // ---------------------------------------------------------------------------

  /// Open a native file picker via a hidden <input type="file"> element.
  void _openFilePicker() {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = true;
    if (widget.accept != null) {
      input.accept = widget.accept!;
    }
    input.addEventListener(
      'change',
      ((web.Event _) {
        final files = input.files;
        if (files != null) {
          for (int i = 0; i < files.length; i++) {
            _readBrowserFile(files.item(i)!);
          }
        }
      }).toJS,
    );
    input.click();
  }

  /// Read a browser File object's bytes via FileReader, then add to the list.
  void _readBrowserFile(web.File browserFile) {
    _idCounter++;
    final id = '${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
    final filename = browserFile.name;
    final fileSize = browserFile.size;

    // Add immediately in uploading state
    final entry = UploadFile(
      id: id,
      filename: filename,
      fileSize: fileSize,
      status: UploadFileStatus.uploading,
      progress: 0.0,
    );
    setState(() {
      _files = [..._files, entry];
    });

    // Read bytes asynchronously
    final reader = web.FileReader();
    reader.addEventListener(
      'load',
      ((web.Event _) {
        final arrayBuffer = reader.result as JSArrayBuffer;
        final bytes = arrayBuffer.toDart.asUint8List();
        _updateFile(
          id,
          status: UploadFileStatus.success,
          progress: 1.0,
          bytes: bytes,
        );
        _notifyParentStateChange();
        _checkAllComplete();
      }).toJS,
    );
    reader.addEventListener(
      'error',
      ((web.Event _) {
        _updateFile(
          id,
          status: UploadFileStatus.error,
          progress: 0.0,
          errorMessage: 'Failed to read file',
        );
        _notifyParentStateChange();
      }).toJS,
    );
    reader.readAsArrayBuffer(browserFile);
  }

  void _retryFile(String fileId) {
    // Remove the failed entry — user must re-pick
    _removeFile(fileId);
    _openFilePicker();
  }

  void _removeFile(String fileId) {
    _uploadTimers[fileId]?.cancel();
    _uploadTimers.remove(fileId);

    setState(() {
      _files = _files.where((f) => f.id != fileId).toList();
    });
    _notifyParentStateChange();
  }

  /// Update file state (status change — notifies parent).
  void _updateFile(
    String fileId, {
    UploadFileStatus? status,
    double? progress,
    String? errorMessage,
    Uint8List? bytes,
  }) {
    setState(() {
      _files = _files.map((f) {
        if (f.id == fileId) {
          return f.copyWith(
            status: status,
            progress: progress,
            errorMessage: errorMessage,
            bytes: bytes,
          );
        }
        return f;
      }).toList();
    });
  }

  void _notifyParentStateChange() {
    widget.onFilesChanged?.call(List.unmodifiable(_files));
  }

  void _checkAllComplete() {
    if (_files.isEmpty) return;
    final allTerminal = _files.every(
      (f) =>
          f.status == UploadFileStatus.success ||
          f.status == UploadFileStatus.error,
    );
    final anySuccess =
        _files.any((f) => f.status == UploadFileStatus.success);
    if (allTerminal && anySuccess) {
      widget.onAllUploadsComplete?.call();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDropArea(),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ..._files.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _FileTile(
                    file: f,
                    isDark: widget.isDark,
                    onRemove: () => _removeFile(f.id),
                    onRetry: f.status == UploadFileStatus.error
                        ? () => _retryFile(f.id)
                        : null,
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildDropArea() {
    final state = _dropAreaState;

    final Color borderColor;
    final Color bgColor;
    final Color iconColor;

    switch (state) {
      case _DropAreaVisualState.empty:
        borderColor =
            widget.isDark ? AppColorsDark.textMuted : AppColors.neutral400;
        bgColor = widget.isDark ? AppColorsDark.surface : AppColors.surface;
        iconColor =
            widget.isDark ? AppColorsDark.textMuted : AppColors.textMuted;
      case _DropAreaVisualState.hover:
      case _DropAreaVisualState.active:
        borderColor =
            widget.isDark ? AppColorsDark.primary : AppColors.primary;
        bgColor =
            widget.isDark ? AppColorsDark.primaryBg : AppColors.primaryBg;
        iconColor =
            widget.isDark ? AppColorsDark.primary : AppColors.primary;
    }

    final labelColor =
        widget.isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _openFilePicker,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: borderColor,
            strokeWidth: 4.0,
            dashWidth: 8.0,
            dashGap: 5.0,
            radius: AppSpacing.radiusMd,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 36, color: iconColor),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.label,
                  style: AppTextStyles.label.copyWith(color: labelColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// File Tile
// =============================================================================

class _FileTile extends StatelessWidget {
  final UploadFile file;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  const _FileTile({
    required this.file,
    required this.isDark,
    required this.onRemove,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final textPrimary =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textMuted = isDark ? AppColorsDark.textMuted : AppColors.textMuted;
    final successColor = isDark ? AppColorsDark.success : AppColors.success;
    final errorColor = isDark ? AppColorsDark.error : AppColors.error;
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;

    // Per-status visuals
    final Color tileBorderColor;
    final Widget statusIcon;
    final Widget detailWidget;

    switch (file.status) {
      case UploadFileStatus.uploading:
        tileBorderColor = primaryColor;
        statusIcon = SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryColor,
          ),
        );
        detailWidget = Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: file.progress,
                  minHeight: 4,
                  backgroundColor:
                      isDark ? AppColorsDark.surfaceElevated : AppColors.neutral200,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 36,
              child: Text(
                '${(file.progress * 100).toInt()}%',
                style: AppTextStyles.bodySmall.copyWith(color: textMuted),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      case UploadFileStatus.success:
        tileBorderColor = successColor;
        statusIcon = Icon(Icons.check_circle, size: 16, color: successColor);
        detailWidget = Text(
          file.fileSizeFormatted,
          style: AppTextStyles.bodySmall.copyWith(color: textMuted),
        );
      case UploadFileStatus.error:
        tileBorderColor = errorColor;
        statusIcon = Icon(Icons.error_outline, size: 16, color: errorColor);
        detailWidget = Text(
          file.errorMessage ?? 'Upload failed',
          style: AppTextStyles.bodySmall.copyWith(color: errorColor),
        );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: tileBorderColor, width: 1.0),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filename,
                  style: AppTextStyles.label.copyWith(color: textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                detailWidget,
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: Icon(Icons.refresh, size: 16, color: primaryColor),
              onPressed: onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Retry',
            ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: textMuted),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dashed Border Painter
// =============================================================================

/// Paints a dashed rounded-rectangle border.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    double distance = 0.0;
    while (distance < totalLength) {
      final end = (distance + dashWidth).clamp(0.0, totalLength);
      final segment = metrics.extractPath(distance, end);
      canvas.drawPath(segment, paint);
      distance += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
