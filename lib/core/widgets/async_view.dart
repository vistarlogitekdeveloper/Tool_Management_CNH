import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'data_grid.dart';

/// Renders an [AsyncValue] with a consistent loading skeleton and a retry-able
/// error state, so no screen has to reimplement the three-state dance.
///
/// While refreshing, the previous data stays on screen with a thin progress
/// line on top — a grid should not blank out when a filter changes.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.showRefreshLine = true,
    this.minLoadingHeight = 220,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool showRefreshLine;
  final double minLoadingHeight;

  @override
  Widget build(BuildContext context) {
    final previous = value.valueOrNull;

    if (value.isLoading && previous == null) {
      return loading ??
          SizedBox(
            height: minLoadingHeight,
            child: const Center(
              child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.6)),
            ),
          );
    }

    if (value.hasError && previous == null) {
      return ErrorPanel(error: value.error!, onRetry: onRetry);
    }

    final content = data(previous as T);
    if (!value.isLoading || !showRefreshLine) return content;

    return Stack(
      children: [
        content,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(minHeight: 2.5),
        ),
      ],
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final isPermission = api?.isForbidden ?? false;
    final isOffline = api?.isNetwork ?? false;

    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? Insets.xl : 40, horizontal: Insets.xl),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPermission
                ? Icons.lock_outline_rounded
                : isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
            size: 34,
            color: isPermission ? AppColors.amber : AppColors.red,
          ),
          const SizedBox(height: Insets.md),
          Text(
            isPermission
                ? 'Not available for your role'
                : isOffline
                    ? 'Cannot reach the TMS server'
                    : 'Something went wrong',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              api?.message ?? error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.55),
            ),
          ),
          if (onRetry != null && !isPermission) ...[
            const SizedBox(height: Insets.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grey placeholder blocks that mimic the shape of a grid while it loads —
/// steadier than a spinner when the whole page is data.
class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, this.rows = 6, this.showHeader = true});

  final int rows;
  final bool showHeader;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (showHeader)
            Container(
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.zebra,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
            ),
          for (var i = 0; i < rows; i++)
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line2)),
              ),
              child: Row(
                children: [
                  _bar(90),
                  const SizedBox(width: Insets.xl),
                  _bar(200),
                  const SizedBox(width: Insets.xl),
                  _bar(120),
                  const Spacer(),
                  _bar(60),
                ],
              ),
            ),
        ],
      );

  Widget _bar(double width) => Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.line2,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

/// A card-shaped skeleton for KPI strips and chart panels.
class BlockSkeleton extends StatelessWidget {
  const BlockSkeleton({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(Insets.radius),
          border: Border.all(color: AppColors.line),
        ),
        child: const Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      );
}

/// Shown when a route exists but the signed-in role may not open it.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, required this.moduleName, this.roleName});

  final String moduleName;
  final String? roleName;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.lock_outline_rounded,
        message:
            '$moduleName is not part of the ${roleName ?? 'current'} role.\n'
            'Ask an administrator if you need access.',
      );
}
