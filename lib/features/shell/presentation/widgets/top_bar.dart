import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/user.dart';

/// Sticky header: global search, the calibration and alert bells, and the
/// signed-in identity with its role.
class TopBar extends StatefulWidget {
  const TopBar({
    super.key,
    required this.user,
    required this.notificationsLink,
    required this.onNotifications,
    required this.onSearch,
    required this.onOpenCalibration,
    required this.onLogout,
    this.unreadCount = 0,
    this.calibrationDue = 0,
    this.onMenu,
  });

  final AuthUser user;
  final LayerLink notificationsLink;
  final VoidCallback onNotifications;
  final void Function(String term) onSearch;
  final VoidCallback onOpenCalibration;
  final VoidCallback onLogout;
  final int unreadCount;
  final int calibrationDue;
  final VoidCallback? onMenu;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.isMobile;

    return Container(
      height: 62,
      padding: EdgeInsets.symmetric(horizontal: compact ? Insets.md : 26),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (widget.onMenu != null)
            IconButton(
              onPressed: widget.onMenu,
              icon: const Icon(Icons.menu_rounded),
              color: AppColors.ink,
              tooltip: 'Menu',
            ),
          if (!compact)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SizedBox(
                width: 420,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (value) {
                    if (value.trim().length > 1) widget.onSearch(value.trim());
                  },
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search tools, employees, part no…',
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
                    prefixIconConstraints: BoxConstraints(minWidth: 36),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ),
            ),
          const Spacer(),
          _iconButton(
            icon: Icons.schedule_rounded,
            tooltip: widget.calibrationDue > 0
                ? '${widget.calibrationDue} calibration(s) due'
                : 'Calibration schedule',
            showDot: widget.calibrationDue > 0,
            onPressed: widget.onOpenCalibration,
          ),
          const SizedBox(width: Insets.sm),
          CompositedTransformTarget(
            link: widget.notificationsLink,
            child: _iconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: widget.unreadCount > 0
                  ? '${widget.unreadCount} unread alert(s)'
                  : 'Alerts',
              showDot: widget.unreadCount > 0,
              onPressed: widget.onNotifications,
            ),
          ),
          const SizedBox(width: Insets.md),
          _userChip(compact),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool showDot = false,
  }) =>
      Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            children: [
              Material(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(Insets.radiusSm),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(Insets.radiusSm),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(Insets.radiusSm),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.slate),
                  ),
                ),
              ),
              if (showDot)
                Positioned(
                  top: 6,
                  right: 7,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _userChip(bool compact) => PopupMenuButton<String>(
        tooltip: widget.user.fullName,
        offset: const Offset(0, 46),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.radius)),
        onSelected: (value) {
          if (value == 'logout') widget.onLogout();
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.user.fullName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                Text(
                  '${widget.user.role.name}${widget.user.department != null ? ' · ${widget.user.department!.name}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                if (widget.user.employeeCode != null)
                  Text(
                    widget.user.employeeCode!,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 16, color: AppColors.red),
                SizedBox(width: 10),
                Text('Sign out', style: TextStyle(fontSize: 13, color: AppColors.red)),
              ],
            ),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialsAvatar(
              widget.user.initials,
              size: 36,
              background: AppColors.brand,
              foreground: Colors.white,
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.user.fullName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.15),
                  ),
                  Text(
                    widget.user.role.name,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.muted),
            ],
          ],
        ),
      );
}
