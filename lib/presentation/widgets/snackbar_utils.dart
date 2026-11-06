import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Default auto-dismiss for ordinary notices (after an operation completes).
const Duration kSnackBarDuration = Duration(milliseconds: 1600);

/// Slightly longer window when the snackbar offers an action.
const Duration kSnackBarActionDuration = Duration(milliseconds: 2800);

/// Log a message to the console with SnackBar context
void _logSnackBar(String message, {String? error, StackTrace? stackTrace}) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] SnackBar: $message';

  if (kDebugMode) {
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('  Error: $error');
    }
  }

  developer.log(
    message,
    name: 'SnackBar',
    error: error,
    stackTrace: stackTrace,
  );
}

Color? _resolveBackground(
  BuildContext context, {
  required bool isError,
  required bool isSuccess,
  Color? backgroundColor,
}) {
  if (backgroundColor != null) return backgroundColor;
  final scheme = Theme.of(context).colorScheme;
  if (isError) return scheme.errorContainer;
  if (isSuccess) return scheme.secondaryContainer;
  // Fall through to [SnackBarThemeData.backgroundColor].
  return null;
}

Color? _resolveContentColor(
  BuildContext context, {
  required bool isError,
  required bool isSuccess,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (isError) return scheme.onErrorContainer;
  if (isSuccess) return scheme.onSecondaryContainer;
  return null;
}

/// Show a SnackBar with automatic logging.
///
/// Colors follow the active theme. After an operation, the bar dismisses
/// quickly; bars with an action stay briefly longer but still hide as soon as
/// the action is pressed.
void showLoggedSnackBar(
  BuildContext context,
  String message, {
  Duration? duration,
  SnackBarAction? action,
  Color? backgroundColor,
  bool isError = false,
  bool isSuccess = false,
}) {
  _logSnackBar(message, error: isError ? message : null);

  final contentColor = _resolveContentColor(
    context,
    isError: isError,
    isSuccess: isSuccess,
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: contentColor == null ? null : TextStyle(color: contentColor),
      ),
      duration: duration ??
          (action != null ? kSnackBarActionDuration : kSnackBarDuration),
      action: action,
      backgroundColor: _resolveBackground(
        context,
        isError: isError,
        isSuccess: isSuccess,
        backgroundColor: backgroundColor,
      ),
    ),
  );
}

/// Show an error SnackBar with automatic logging
void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration? duration,
  SnackBarAction? action,
  Object? error,
  StackTrace? stackTrace,
}) {
  _logSnackBar(message, error: error?.toString(), stackTrace: stackTrace);
  showLoggedSnackBar(
    context,
    message,
    duration: duration,
    action: action,
    isError: true,
  );
}

/// Show a success SnackBar with automatic logging
void showSuccessSnackBar(
  BuildContext context,
  String message, {
  Duration? duration,
  SnackBarAction? action,
}) {
  _logSnackBar(message);
  showLoggedSnackBar(
    context,
    message,
    duration: duration ?? const Duration(milliseconds: 1200),
    action: action,
    isSuccess: true,
  );
}

/// Extension on ScaffoldMessengerState to add logging
extension LoggedSnackBarExtension on ScaffoldMessengerState {
  /// Show a SnackBar with automatic logging
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoggedSnackBar(
    SnackBar snackBar, {
    String? logMessage,
  }) {
    final message = logMessage ??
        (snackBar.content is Text
            ? (snackBar.content as Text).data
            : 'SnackBar shown');
    _logSnackBar(message ?? 'SnackBar shown');
    return showSnackBar(snackBar);
  }
}
