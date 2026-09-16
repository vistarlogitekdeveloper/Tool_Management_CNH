import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The prototype's modal: title bar, scrollable body, right-aligned footer.
///
/// On a phone it presents as a full-height bottom sheet instead of a centred
/// card, which is the right shape for a one-handed shop-floor entry.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.width = 560,
    this.icon,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final IconData? icon;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        Flexible(
          child: scrollable
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                )
              : Padding(padding: const EdgeInsets.all(20), child: child),
        ),
        if (actions.isNotEmpty) _footer(),
      ],
    );

    if (context.isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Material(
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
              child: body,
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: body,
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, Insets.md, 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(Insets.radiusSm),
                ),
                child: Icon(icon, size: 17, color: AppColors.brand),
              ),
              const SizedBox(width: Insets.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.muted,
              tooltip: 'Close',
            ),
          ],
        ),
      );

  Widget _footer() => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          color: AppColors.zebra,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              actions[i],
            ],
          ],
        ),
      );
}

/// Presents [dialog] as a dialog on desktop and a bottom sheet on a phone.
Future<T?> showAppDialog<T>(BuildContext context, Widget dialog, {bool dismissible = true}) {
  if (context.isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      builder: (_) => dialog,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (_) => dialog,
  );
}

/// Right-side detail panel for a record; a full-screen route on a phone.
Future<T?> showDetailSheet<T>(BuildContext context, Widget child, {double width = 720}) {
  if (context.isMobile) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => child, fullscreenDialog: true),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: child,
      ),
    ),
  );
}
