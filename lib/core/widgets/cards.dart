import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The panel every screen is built from: white, hairline border, soft shadow,
/// optional header row with a title and a trailing action.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.showHeaderDivider = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsets padding;
  final bool showHeaderDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(Insets.radius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(Insets.lg, 14, Insets.lg, 14),
              decoration: showHeaderDivider
                  ? const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.line2)),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title!, style: Theme.of(context).textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          if (child != null) Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// KPI tile: icon chip, label, big number, delta caption.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = KpiTone.blue,
    this.caption,
    this.captionTone,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final KpiTone tone;
  final String? caption;
  final KpiTone? captionTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colours;

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(Insets.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Insets.radius),
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Insets.radius),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Insets.radiusSm),
                    ),
                    child: Icon(icon, size: 18, color: fg),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 12,
                    color: (captionTone ?? KpiTone.slate).colours.$2,
                    fontWeight: captionTone == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum KpiTone {
  blue,
  green,
  amber,
  red,
  violet,
  slate;

  (Color, Color) get colours => switch (this) {
        KpiTone.blue => (AppColors.brandSoft, AppColors.brand),
        KpiTone.green => (AppColors.greenSoft, AppColors.green),
        KpiTone.amber => (AppColors.amberSoft, AppColors.amber),
        KpiTone.red => (AppColors.redSoft, AppColors.red),
        KpiTone.violet => (AppColors.violetSoft, AppColors.violet),
        KpiTone.slate => (AppColors.slateSoft, AppColors.slate),
      };
}

/// The KPI strip — responsive column count, equal heights.
class KpiStrip extends StatelessWidget {
  const KpiStrip({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) =>
      ResponsiveGrid(columns: context.kpiColumns, children: cards);
}

/// Page title block: breadcrumb, heading, subtitle, right-aligned actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.breadcrumb,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? breadcrumb;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (breadcrumb != null) ...[
          Text(breadcrumb!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ],
    );

    if (actions.isEmpty) {
      return Padding(padding: const EdgeInsets.only(bottom: 18), child: heading);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: Insets.md),
                Wrap(spacing: Insets.sm, runSpacing: Insets.sm, children: actions),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                const SizedBox(width: Insets.lg),
                Wrap(spacing: Insets.sm, runSpacing: Insets.sm, children: actions),
              ],
            ),
    );
  }
}

/// The amber advisory strip (`.note` in the prototype).
class NoticeBar extends StatelessWidget {
  const NoticeBar({
    super.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
    this.tone = NoticeTone.warning,
    this.action,
  });

  final String message;
  final IconData icon;
  final NoticeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (tone) {
      NoticeTone.warning => (AppColors.amberSoft, const Color(0xFFF0DCAE), const Color(0xFF8A5E0E)),
      NoticeTone.danger => (AppColors.redSoft, const Color(0xFFF0C4C4), AppColors.redInk),
      NoticeTone.info => (AppColors.brandSoft, const Color(0xFFC6DBF5), AppColors.brand),
      NoticeTone.success => (AppColors.greenSoft, const Color(0xFFBFE7CF), AppColors.greenInk),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.lg),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(Insets.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: fg, height: 1.45, fontWeight: FontWeight.w500),
            ),
          ),
          if (action != null) ...[const SizedBox(width: Insets.sm), action!],
        ],
      ),
    );
  }
}

enum NoticeTone { warning, danger, info, success }

/// Label/value row used inside detail sheets (`.kv`).
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value, this.valueWidget});

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              flex: 3,
              child: valueWidget ??
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
            ),
          ],
        ),
      );
}
