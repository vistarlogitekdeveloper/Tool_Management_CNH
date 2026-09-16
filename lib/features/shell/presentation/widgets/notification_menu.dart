import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/alert.dart';
import '../../../../models/enums.dart';
import '../../../alerts/data/alerts_repository.dart';

/// The bell dropdown. Anchors to the top bar's bell on desktop and fills the
/// screen width on a phone.
class NotificationMenu extends ConsumerWidget {
  const NotificationMenu({
    super.key,
    required this.link,
    required this.onDismiss,
    required this.onOpen,
  });

  final LayerLink link;
  final VoidCallback onDismiss;
  final void Function(String? route) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationFeedProvider);
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 420 ? width - 24 : 360.0;

    return Stack(
      children: [
        // Catches taps outside the panel.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(6, 10),
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                constraints: const BoxConstraints(maxHeight: 460),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Insets.radiusLg),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppShadows.popover,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(context, ref, feed.valueOrNull),
                    Flexible(
                      child: feed.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(Insets.xl),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                          ),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.all(Insets.xl),
                          child: Text(
                            'Could not load alerts.\n$error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ),
                        data: (data) => data.items.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 36, horizontal: Insets.lg),
                                child: Column(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 28, color: AppColors.green),
                                    SizedBox(height: 10),
                                    Text(
                                      'Nothing needs your attention',
                                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: data.items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: AppColors.line2),
                                itemBuilder: (context, i) => _item(context, ref, data.items[i]),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, NotificationFeed? feed) => Container(
        padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.sm, Insets.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: Insets.sm),
            if ((feed?.unreadCount ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${feed!.unreadCount} new',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.redInk,
                  ),
                ),
              ),
            const Spacer(),
            if ((feed?.unreadCount ?? 0) > 0)
              TextButton(
                onPressed: () async {
                  await ref.read(alertsRepositoryProvider).markRead(all: true);
                  ref.invalidate(notificationFeedProvider);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Mark all read', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
      );

  Widget _item(BuildContext context, WidgetRef ref, AppNotification n) {
    final palette = StatusStyles.of(n.severity ?? 'INFO');

    return InkWell(
      onTap: () async {
        if (!n.isRead) {
          await ref.read(alertsRepositoryProvider).markRead(ids: [n.id]);
          ref.invalidate(notificationFeedProvider);
        }
        onOpen(_routeFor(n));
      },
      child: Container(
        color: n.isRead ? null : AppColors.brandSoft.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: palette.foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                  if (n.body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    Fmt.ago(n.createdAt),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Alert links come from the server as app-relative paths.
  String? _routeFor(AppNotification n) {
    final link = n.link;
    if (link == null || link.isEmpty) return null;
    // Strip any query the server attached — the destination screen re-queries.
    final path = link.split('?').first;
    return switch (path.split('/').where((s) => s.isNotEmpty).firstOrNull) {
      'inventory' => '/inventory',
      'calibration' => '/calibration',
      'issues' => '/issues',
      'maintenance' => '/maintenance',
      'purchase' => '/purchase',
      _ => '/alerts',
    };
  }
}
