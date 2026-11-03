import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';

/// Confirms a destructive action when [AppSettings.confirmBeforeDelete] is on.
///
/// Returns `true` when the action should proceed.
Future<bool> confirmDestructiveAction(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  String? confirmLabel,
}) async {
  if (!ref.read(appSettingsProvider).confirmBeforeDelete) {
    return true;
  }

  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(confirmLabel ?? l10n.delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}
