import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Ring chart with a centred total — the prototype's "Fleet by Status" donut.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 140,
    this.strokeWidth = 20,
    this.centreLabel = 'TOTAL',
    this.centreValue,
  });

  final List<ChartSlice> slices;
  final double size;
  final double strokeWidth;
  final String centreLabel;

  /// Overrides the summed total shown in the middle.
  final String? centreValue;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value.toDouble());

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(slices: slices, strokeWidth: strokeWidth, total: total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centreValue ?? Fmt.int_(total),
                style: TextStyle(
                  fontSize: size * 0.17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              Text(
                centreLabel,
                style: TextStyle(
                  fontSize: size * 0.075,
                  color: AppColors.muted,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.strokeWidth, required this.total});

  final List<ChartSlice> slices;
  final double strokeWidth;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.line2;
    canvas.drawCircle(centre, radius, track);

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = slice.colour;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.strokeWidth != strokeWidth || old.slices != slices;
}

/// Legend rows beside a donut: swatch, label, right-aligned count.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.slices, this.showPercent = false, this.onTap});

  final List<ChartSlice> slices;
  final bool showPercent;
  final void Function(ChartSlice slice)? onTap;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final slice in slices)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(slice),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.5),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: slice.colour,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      slice.label,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showPercent && total > 0) ...[
                    Text(
                      '${((slice.value / total) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                    const SizedBox(width: Insets.sm),
                  ],
                  Text(
                    Fmt.int_(slice.value),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
