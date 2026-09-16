import 'package:flutter/widgets.dart';

import '../config/app_config.dart';

enum ScreenSize { mobile, tablet, desktop, wide }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  ScreenSize get screenSize {
    final w = screenWidth;
    if (w < AppConfig.mobileBreakpoint) return ScreenSize.mobile;
    if (w < AppConfig.tabletBreakpoint) return ScreenSize.tablet;
    if (w < AppConfig.desktopBreakpoint) return ScreenSize.desktop;
    return ScreenSize.wide;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenWidth >= AppConfig.tabletBreakpoint;

  /// The sidebar is permanent on desktop and a drawer below that.
  bool get hasPermanentSidebar => screenWidth >= AppConfig.tabletBreakpoint;

  /// KPI strip: 4 across on desktop, 2 on tablet, 1 on a phone.
  int get kpiColumns => switch (screenSize) {
        ScreenSize.mobile => 2,
        ScreenSize.tablet => 2,
        _ => 4,
      };

  int get cardColumns => switch (screenSize) {
        ScreenSize.mobile => 1,
        ScreenSize.tablet => 2,
        _ => 3,
      };

  double get pageGutter => isMobile ? 14 : 26;

  /// Pick a value per breakpoint without a switch at every call site.
  T responsive<T>({required T mobile, T? tablet, T? desktop, T? wide}) => switch (screenSize) {
        ScreenSize.mobile => mobile,
        ScreenSize.tablet => tablet ?? mobile,
        ScreenSize.desktop => desktop ?? tablet ?? mobile,
        ScreenSize.wide => wide ?? desktop ?? tablet ?? mobile,
      };
}

/// Lays children into a responsive grid without needing fixed aspect ratios —
/// each cell sizes to its content, which KPI tiles and chart cards need.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    required this.columns,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns.clamp(1, children.length);
        final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: width.clamp(140.0, constraints.maxWidth), child: child),
          ],
        );
      },
    );
  }
}

/// Two-column layout that stacks below the tablet breakpoint. `flex` controls
/// the desktop split (2:1 by default, matching the prototype's `.cols-2`).
class SplitRow extends StatelessWidget {
  const SplitRow({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 2,
    this.rightFlex = 1,
    this.spacing = 16,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, SizedBox(height: spacing), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        SizedBox(width: spacing),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}
