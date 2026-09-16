import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Filled trend line for "Tool Issues — Last 7 Days", with a day-labelled axis
/// and a tap-to-inspect readout.
class SparkAreaChart extends StatefulWidget {
  const SparkAreaChart({
    super.key,
    required this.points,
    this.height = 120,
    this.colour = AppColors.brand,
    this.compareColour = AppColors.green,
    this.showReturns = true,
  });

  final List<TrendPoint> points;
  final double height;
  final Color colour;
  final Color compareColour;

  /// Overlays the returns series so issues-out and items-back read together.
  final bool showReturns;

  @override
  State<SparkAreaChart> createState() => _SparkAreaChartState();
}

class _SparkAreaChartState extends State<SparkAreaChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('Not enough data yet', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ),
      );
    }

    final selected = _hoverIndex != null && _hoverIndex! < widget.points.length
        ? widget.points[_hoverIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) => MouseRegion(
              onHover: (event) => _updateHover(event.localPosition.dx, constraints.maxWidth),
              onExit: (_) => setState(() => _hoverIndex = null),
              child: GestureDetector(
                onTapDown: (d) => _updateHover(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (d) => _updateHover(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragEnd: (_) => setState(() => _hoverIndex = null),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _SparkPainter(
                    points: widget.points,
                    colour: widget.colour,
                    compareColour: widget.compareColour,
                    showReturns: widget.showReturns,
                    hoverIndex: _hoverIndex,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final point in widget.points)
              Expanded(
                child: Text(
                  _dayLabel(point.date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: Insets.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${Fmt.date(selected.date)} · ${selected.issues} issue(s), '
              '${selected.qty} unit(s) out, ${selected.returns} returned',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.brand, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  void _updateHover(double dx, double width) {
    final step = width / (widget.points.length - 1);
    final index = (dx / step).round().clamp(0, widget.points.length - 1);
    if (index != _hoverIndex) setState(() => _hoverIndex = index);
  }

  static String _dayLabel(DateTime d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.points,
    required this.colour,
    required this.compareColour,
    required this.showReturns,
    this.hoverIndex,
  });

  final List<TrendPoint> points;
  final Color colour;
  final Color compareColour;
  final bool showReturns;
  final int? hoverIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points.fold<double>(
      1,
      (m, p) => math.max(m, math.max(p.issues.toDouble(), showReturns ? p.returns.toDouble() : 0)),
    );
    final step = size.width / (points.length - 1);
    // Leave headroom so the peak isn't glued to the top edge.
    final usableHeight = size.height * 0.88;

    Offset at(int i, num value) =>
        Offset(i * step, size.height - (value / maxValue) * usableHeight);

    // Horizontal guide lines.
    final guide = Paint()
      ..color = AppColors.line2
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height - (usableHeight * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    _drawSeries(canvas, size, points.map((p) => p.issues).toList(), at, colour, fill: true);
    if (showReturns) {
      _drawSeries(canvas, size, points.map((p) => p.returns).toList(), at, compareColour,
          fill: false, dashed: true);
    }

    // Point markers on the primary series.
    for (var i = 0; i < points.length; i++) {
      final centre = at(i, points[i].issues);
      final isHover = i == hoverIndex;
      canvas.drawCircle(centre, isHover ? 5 : 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        centre,
        isHover ? 5 : 3,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHover ? 2.6 : 2,
      );
    }

    if (hoverIndex != null) {
      final x = hoverIndex! * step;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = colour.withValues(alpha: 0.28)
          ..strokeWidth = 1.4,
      );
    }
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<int> values,
    Offset Function(int, num) at,
    Color seriesColour, {
    required bool fill,
    bool dashed = false,
  }) {
    final path = Path()..moveTo(at(0, values[0]).dx, at(0, values[0]).dy);
    for (var i = 1; i < values.length; i++) {
      final p = at(i, values[i]);
      path.lineTo(p.dx, p.dy);
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0),
            Offset(0, size.height),
            [seriesColour.withValues(alpha: 0.24), seriesColour.withValues(alpha: 0.02)],
          ),
      );
    }

    final stroke = Paint()
      ..color = seriesColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = fill ? 2.5 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dashed ? _dash(path) : path, stroke);
  }

  /// Approximates a dashed stroke; Flutter has no native dash pattern.
  Path _dash(Path source, {double dashLength = 5, double gap = 4}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        result.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gap;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.points != points || old.hoverIndex != hoverIndex || old.showReturns != showReturns;
}
