import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';

/// Single-slot draft for the moments compose page.
class MomentsComposeDraft {
  const MomentsComposeDraft({
    required this.body,
    this.imagePath,
  });

  final String body;
  final String? imagePath;

  bool get hasContent =>
      body.trim().isNotEmpty || (imagePath != null && imagePath!.isNotEmpty);
}

final momentsComposeDraftProvider = StateNotifierProvider<
    MomentsComposeDraftNotifier, MomentsComposeDraft?>((ref) {
  return MomentsComposeDraftNotifier(ref.watch(sharedPreferencesProvider));
});

class MomentsComposeDraftNotifier extends StateNotifier<MomentsComposeDraft?> {
  MomentsComposeDraftNotifier(this._prefs) : super(_load(_prefs));

  static const _bodyKey = 'moments_compose_draft_body';
  static const _imageKey = 'moments_compose_draft_image';

  final SharedPreferences _prefs;

  static MomentsComposeDraft? _load(SharedPreferences prefs) {
    final body = prefs.getString(_bodyKey) ?? '';
    final imagePath = prefs.getString(_imageKey);
    final draft = MomentsComposeDraft(body: body, imagePath: imagePath);
    return draft.hasContent ? draft : null;
  }

  /// Replaces the only draft slot. Empty content clears the slot.
  Future<void> save({required String body, String? imagePath}) async {
    final draft = MomentsComposeDraft(
      body: body.trim(),
      imagePath: imagePath,
    );
    if (!draft.hasContent) {
      await clear();
      return;
    }
    state = draft;
    await _prefs.setString(_bodyKey, draft.body);
    if (draft.imagePath != null && draft.imagePath!.isNotEmpty) {
      await _prefs.setString(_imageKey, draft.imagePath!);
    } else {
      await _prefs.remove(_imageKey);
    }
  }

  Future<void> clear() async {
    state = null;
    await _prefs.remove(_bodyKey);
    await _prefs.remove(_imageKey);
  }
}

/// Shared leave guard for cancel button, system back, and play-hub / tab
/// switches (via [GoRoute.onExit]).
///
/// Returns `true` when navigation may proceed.
Future<bool> confirmMomentsComposeLeave(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final draft = container.read(momentsComposeDraftProvider);
  if (draft == null || !draft.hasContent) {
    return true;
  }

  final l10n = AppLocalizations.of(context);
  final save = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.momentsDraftSaveTitle),
      content: Text(l10n.momentsDraftSaveMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.momentsDraftDiscard),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.momentsDraftSave),
        ),
      ],
    ),
  );
  if (save == null) {
    return false;
  }
  if (!save) {
    await container.read(momentsComposeDraftProvider.notifier).clear();
  }
  return true;
}
