import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/files/data/files_repository.dart';
import '../../models/tool.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/downloader.dart';
import '../utils/feedback.dart';

/// Upload / open / remove one attachment.
///
/// The RFQ asks for drawing (PDF/DWG), tool image and calibration certificate
/// upload. This is the single control behind all three: it picks a file,
/// uploads it to `POST /files`, and hands the resulting attachment id back so
/// the caller can save it on the parent record.
///
/// It deliberately does not save anything itself — the id goes to the parent
/// form, which decides whether that means an immediate PATCH (tool detail) or a
/// field on a record about to be created (calibration certificate).
class AttachmentField extends ConsumerStatefulWidget {
  const AttachmentField({
    super.key,
    required this.category,
    required this.onChanged,
    this.attachmentId,
    this.fileName,
    this.label,
    this.enabled = true,
    this.entityType,
    this.entityId,
    this.dense = false,
  });

  final AttachmentCategory category;

  /// Called with the new attachment id, or null when the file is removed.
  final ValueChanged<String?> onChanged;

  /// The attachment already on the record, if any.
  final String? attachmentId;
  final String? fileName;

  /// Defaults to the category label ("Drawing", "Photo", "Certificate").
  final String? label;

  /// False for a role that may view but not change the record.
  final bool enabled;

  /// Tags the upload against its parent immediately, when the parent exists.
  final String? entityType;
  final String? entityId;

  /// Compact single-line presentation, for use inside a detail sheet row.
  final bool dense;

  @override
  ConsumerState<AttachmentField> createState() => _AttachmentFieldState();
}

class _AttachmentFieldState extends ConsumerState<AttachmentField> {
  bool _busy = false;
  double? _progress;

  /// Name of the file uploaded in this session, so the row can show something
  /// more useful than "on file" straight after an upload.
  String? _justUploadedName;

  bool get _hasFile => widget.attachmentId != null;

  String get _label => widget.label ?? widget.category.label;

  Future<void> _pickAndUpload() async {
    final repo = ref.read(filesRepositoryProvider);
    try {
      final picked = await repo.pick(widget.category);
      if (picked == null) return; // cancelled

      setState(() {
        _busy = true;
        _progress = 0;
      });

      final attachment = await repo.upload(
        picked,
        widget.category,
        entityType: widget.entityType,
        entityId: widget.entityId,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = sent / total);
        },
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _justUploadedName = attachment.fileName;
      });
      widget.onChanged(attachment.id);
      if (mounted) {
        context.toast('$_label uploaded — ${attachment.fileName} (${attachment.sizeLabel})');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      context.showApiError(error);
    }
  }

  Future<void> _open() async {
    final id = widget.attachmentId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final file = await ref.read(filesRepositoryProvider).download(
            id,
            fallbackName: _displayName,
          );
      final message = await Downloader.save(file);
      if (mounted) context.toast(message);
    } catch (error) {
      if (mounted) context.showApiError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirm(
      context,
      title: 'Remove ${_label.toLowerCase()}?',
      message: 'The file stays in the archive; it is only detached from this record.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _justUploadedName = null);
    widget.onChanged(null);
  }

  String get _displayName =>
      _justUploadedName ?? widget.fileName ?? '${_label.toLowerCase()}.${widget.category.extensions.first}';

  @override
  Widget build(BuildContext context) {
    if (_busy && _progress != null) {
      return _shell(
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, value: _progress),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              'Uploading… ${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    if (!_hasFile) {
      return _shell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.enabled)
              _action(
                icon: Icons.upload_file_outlined,
                label: 'Upload ${_label.toLowerCase()}',
                onTap: _busy ? null : _pickAndUpload,
              )
            else
              const Text(
                'Not uploaded',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            if (widget.enabled && !widget.dense) ...[
              const SizedBox(width: Insets.sm),
              Text(
                widget.category.extensionHint,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ],
        ),
      );
    }

    return _shell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InkWell(
              onTap: _busy ? null : _open,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.category == AttachmentCategory.image
                        ? Icons.image_outlined
                        : Icons.description_outlined,
                    size: 15,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.enabled) ...[
            const SizedBox(width: Insets.sm),
            _iconAction(Icons.swap_horiz_rounded, 'Replace', _busy ? null : _pickAndUpload),
            _iconAction(Icons.close_rounded, 'Remove', _busy ? null : _remove),
          ],
        ],
      ),
    );
  }

  /// Dense mode is a bare row for a KeyValueRow; otherwise it gets a label above.
  Widget _shell(Widget child) {
    if (widget.dense) {
      return Align(alignment: Alignment.centerRight, child: child);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.hover,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(Insets.radiusSm),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _action({required IconData icon, required String label, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: onTap == null ? AppColors.muted : AppColors.brand),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? AppColors.muted : AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _iconAction(IconData icon, String tooltip, VoidCallback? onTap) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 15, color: AppColors.muted),
          ),
        ),
      );
}

/// The attachment currently on a record, when the caller has the full object.
extension AttachmentLookup on List<Attachment> {
  Attachment? byId(String? id) {
    if (id == null) return null;
    for (final a in this) {
      if (a.id == id) return a;
    }
    return null;
  }
}
