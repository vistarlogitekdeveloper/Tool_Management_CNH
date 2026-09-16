import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Vertical bars with the value printed above each — "Tools by Category" and
/// "Utilisation by Shop" in the prototype.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.slices,
    this.height = 170,
    this.maxValue,
    this.valueSuffix = '',
    this.onTap,
  });

  final List<ChartSlice> slices;
  final double height;

  /// Fixes the y-axis (e.g. 100 for percentages); otherwise scales to the data.
  final double? maxValue;
  final String valueSuffix;
  final void Function(ChartSlice slice)? onTap;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ),
      );
    }

    final max = maxValue ??
        slices.fold<double>(1, (m, s) => math.max(m, s.value.toDouble()));
    const labelBlock = 34.0;
    const valueBlock = 18.0;
    final barArea = (height - labelBlock - valueBlock).clamp(20.0, height);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final slice in slices)
            Expanded(
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(slice),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: valueBlock,
                        child: FittedBox(
                          child: Text(
                            '${Fmt.int_(slice.value)}$valueSuffix',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0, end: (slice.value / max).clamp(0.0, 1.0)),
                        builder: (context, t, _) => Container(
                          height: math.max(3, barArea * t),
                          constraints: const BoxConstraints(maxWidth: 40),
                          decoration: BoxDecoration(
                            color: slice.colour,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: labelBlock - 7,
                        child: Text(
                          slice.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal bars with the label inline — better than vertical bars when the
/// categories have long names (vendors, shops, tools).
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.slices,
    this.maxValue,
    this.valueFormatter,
    this.barHeight = 9,
    this.showRank = false,
  });

  final List<ChartSlice> slices;
  final double? maxValue;
  final String Function(num value)? valueFormatter;
  final double barHeight;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Insets.xl),
        child: Center(
          child: Text('No data', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ),
      );
    }

    final max = maxValue ?? slices.fold<double>(1, (m, s) => math.max(m, s.value.toDouble()));
    final format = valueFormatter ?? Fmt.int_;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == slices.length - 1 ? 0 : 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (showRank) ...[
                      SizedBox(
                        width: 18,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        slices[i].label,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(
                      format(slices[i].value),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(barHeight),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: (slices[i].value / max).clamp(0.0, 1.0)),
                    builder: (context, t, _) => LinearProgressIndicator(
                      value: t,
                      minHeight: barHeight,
                      backgroundColor: AppColors.line,
                      valueColor: AlwaysStoppedAnimation<Color>(slices[i].colour),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
