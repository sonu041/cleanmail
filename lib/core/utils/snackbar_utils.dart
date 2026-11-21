import 'dart:async';
import 'package:flutter/material.dart';

/// Utility methods for displaying SnackBars with guaranteed auto-hide behavior.
class SnackBarUtils {
  /// Displays a SnackBar with a guaranteed auto-hide timeout (default 5 seconds).
  ///
  /// On desktop platforms (Windows, macOS, Linux) and Web, Flutter's default
  /// [SnackBar] dismissal timer pauses indefinitely whenever the mouse cursor
  /// enters or hovers over the bottom region where the SnackBar appears.
  /// Additionally, when accessibility services or screen readers signal
  /// `accessibleNavigation`, Flutter disables the internal timer entirely.
  ///
  /// This utility creates an explicit [Timer] that calls [controller.close]
  /// after [duration], ensuring the notification reliably auto-hides after
  /// exactly 5 seconds regardless of cursor hover or accessibility settings.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAutoHideSnackBar({
    required ScaffoldMessengerState messenger,
    required String message,
    VoidCallback? onUndo,
    Duration duration = const Duration(seconds: 5),
    SnackBarBehavior? behavior,
    SnackBarAction? customAction,
    Color? backgroundColor,
  }) {
    messenger.hideCurrentSnackBar();

    Timer? forceTimer;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;

    final action = customAction ??
        (onUndo != null
            ? SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  forceTimer?.cancel();
                  onUndo();
                },
              )
            : null);

    controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: behavior,
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );

    forceTimer = Timer(duration, () {
      try {
        controller.close();
      } catch (_) {}
    });

    // Clean up timer if dismissed before timeout (e.g. via Undo tap or another SnackBar)
    controller.closed.then((_) {
      forceTimer?.cancel();
    });

    return controller;
  }
}
