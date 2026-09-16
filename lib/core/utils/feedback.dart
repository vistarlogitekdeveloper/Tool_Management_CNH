import 'dart:async';

import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The prototype's toast, as a floating SnackBar.
enum ToastKind { success, warning, error, info }

extension Toasts on BuildContext {
  void toast(String message, {ToastKind kind = ToastKind.success, Duration? duration}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    final (bg, icon) = switch (kind) {
      ToastKind.success => (const Color(0xFF14713F), Icons.check_circle_outline),
      ToastKind.warning => (const Color(0xFF9A6A10), Icons.warning_amber_rounded),
      ToastKind.error => (AppColors.redInk, Icons.error_outline),
      ToastKind.info => (AppColors.navBg, Icons.info_outline),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: bg,
          duration: duration ?? Duration(seconds: kind == ToastKind.error ? 5 : 3),
          width: MediaQuery.sizeOf(this).width > 640 ? 560 : null,
          margin: MediaQuery.sizeOf(this).width > 640 ? null : const EdgeInsets.all(Insets.md),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
  }

  /// Presents an ApiException with the tone its status deserves — a business
  /// rule ("only 4 available") is a warning, not a red error.
  void showApiError(Object error) {
    if (error is ApiException) {
      toast(
        error.message,
        kind: error.isBusinessRule || error.isConflict ? ToastKind.warning : ToastKind.error,
      );
      return;
    }
    toast(error.toString(), kind: ToastKind.error);
  }
}

/// Yes/no confirmation. Returns true only on an explicit confirm.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Widget? extra,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.5)),
          if (extra != null) ...[const SizedBox(height: Insets.md), extra],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel, style: const TextStyle(color: AppColors.muted)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.red) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Blocks the screen while an async action runs, then reports the outcome.
/// Returns the action's value, or null if it threw (the error is toasted).
Future<T?> runWithProgress<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? successMessage,
  bool showSpinner = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var spinnerShown = false;

  if (showSpinner) {
    spinnerShown = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        ),
      ),
    ));
  }

  try {
    final result = await action();
    if (spinnerShown && navigator.canPop()) navigator.pop();
    if (context.mounted && successMessage != null) context.toast(successMessage);
    return result;
  } catch (error) {
    if (spinnerShown && navigator.canPop()) navigator.pop();
    if (context.mounted) context.showApiError(error);
    return null;
  }
}
