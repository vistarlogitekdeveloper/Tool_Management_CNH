import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The prototype's pill: a dot, a label, a soft tinted background.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label, this.dense = false, this.palette});

  /// The raw status token, e.g. 'DUE_SOON'.
  final String? status;

  /// Overrides the humanised token.
  final String? label;
  final bool dense;
  final StatusPalette? palette;

  @override
  Widget build(BuildContext context) {
    if (status == null || status!.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.muted, fontSize: 12));
    }
    final p = palette ?? StatusStyles.of(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 1.5 : 3),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(Insets.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: p.foreground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label ?? StatusStyles.label(status),
            style: TextStyle(
              color: p.foreground,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Category pill, tinted from the category's own colour.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.name, required this.colour, this.dense = false});

  final String name;
  final Color colour;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 1.5 : 3),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Insets.chipRadius),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: colour,
            fontSize: dense ? 10.5 : 11.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      );
}

/// A count badge for sidebar items and tabs.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.colour = AppColors.red});

  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(10)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Tool codes, PO numbers, certificate numbers.
class MonoText extends StatelessWidget {
  const MonoText(this.text, {super.key, this.colour, this.size});

  final String text;
  final Color? colour;
  final double? size;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: kMonoStyle.copyWith(color: colour, fontSize: size),
      );
}

/// Circular initials avatar, matching `.avatar-sm` in the prototype.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 28, this.background, this.foreground});

  final String initials;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background ?? AppColors.slateSoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          initials,
          style: TextStyle(
            color: foreground ?? AppColors.slate,
            fontSize: size * 0.40,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Thin stock-level bar (`.prog` in the prototype).
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.percent, required this.colour, this.height = 7});

  final double percent;
  final Color colour;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: (percent / 100).clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: AppColors.line,
          valueColor: AlwaysStoppedAnimation<Color>(colour),
        ),
      );

  /// Green when healthy, amber under half, red when at or below minimum.
  static Color colourFor({required double percent, required bool isLow}) {
    if (isLow) return AppColors.red;
    if (percent < 50) return AppColors.amber;
    return AppColors.green;
  }
}
