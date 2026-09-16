import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/downloader.dart';
import '../../../../core/utils/feedback.dart';
import '../../data/reports_repository.dart';

/// Excel / PDF / CSV export button. Every report and grid uses this one control,
/// so "exportable to Excel and PDF" behaves identically wherever it appears.
class ExportButton extends ConsumerStatefulWidget {
  const ExportButton({
    super.key,
    required this.reportKey,
    this.label = 'Export',
    this.filters = const ReportFilters(),
    this.filled = false,
  });

  final String reportKey;
  final String label;
  final ReportFilters filters;
  final bool filled;

  @override
  ConsumerState<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<ExportButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.file_download_outlined, size: 16);

    return PopupMenuButton<String>(
      enabled: !_busy,
      tooltip: 'Export this view',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: _export,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'xlsx',
          height: 42,
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, size: 17, color: AppColors.green),
              SizedBox(width: 10),
              Text('Excel workbook (.xlsx)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'pdf',
          height: 42,
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 17, color: AppColors.red),
              SizedBox(width: 10),
              Text('PDF report (.pdf)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'csv',
          height: 42,
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 17, color: AppColors.slate),
              SizedBox(width: 10),
              Text('CSV data (.csv)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      // A plain container, not a Button: a disabled Material button would
      // swallow the tap that PopupMenuButton needs.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: widget.filled ? AppColors.brand : AppColors.panel,
          border: Border.all(color: widget.filled ? AppColors.brand : AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                size: 16,
                color: widget.filled ? Colors.white : AppColors.ink,
              ),
              child: icon,
            ),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.filled ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: widget.filled ? Colors.white70 : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(String format) async {
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(reportsRepositoryProvider)
          .export(widget.reportKey, widget.filters, format);
      final message = await Downloader.save(file);
      if (mounted) context.toast(message);
    } catch (error) {
      if (mounted) context.showApiError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
