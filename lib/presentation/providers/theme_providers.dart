import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/theme/app_theme_mode.dart';
import '../../data/models/theme/theme_appearance.dart';
import '../../data/models/theme/theme_color_pack.dart';
import '../../data/models/theme/theme_tokens.dart';
import '../../data/models/theme/ui_preferences.dart';
import '../theme/native_tavern_theme.dart';
import 'settings_providers.dart';

const String _themeAppearanceKey = 'theme_appearance_v2';

/// Live theme state: persisted appearance + platform brightness for system mode.
class ThemeState {
  const ThemeState({
    required this.appearance,
    required this.platformBrightness,
  });

  final ThemeAppearance appearance;
  final Brightness platformBrightness;

  AppThemeMode get themeMode => appearance.mode;
  ThemeTokens get lightTokens => appearance.lightTokens;
  ThemeTokens get darkTokens => appearance.darkTokens;
  String get lightPackId => appearance.lightPackId;
  String get darkPackId => appearance.darkPackId;
  List<ThemeColorPack> get customPacks => appearance.customPacks;
  UiPreferences get ui => appearance.ui;

  List<ThemeColorPack> get colorPacks => [
        ...ThemeColorPack.builtIns,
        ...customPacks,
      ];

  bool get isEffectivelyDark => switch (themeMode) {
        AppThemeMode.dark => true,
        AppThemeMode.light => false,
        AppThemeMode.system => platformBrightness == Brightness.dark,
      };

  ThemeTokens get tokens => isEffectivelyDark ? darkTokens : lightTokens;

  String get activePackId => isEffectivelyDark ? darkPackId : lightPackId;

  ThemeColorPack? get activePack => packById(activePackId);

  bool get isActivePackCustomized {
    final pack = activePack;
    return pack == null || pack.tokens != tokens;
  }

  ThemeData get themeData => buildNativeTavernTheme(tokens, ui: ui);

  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  ThemeColorPack? packById(String id) {
    for (final pack in ThemeColorPack.builtIns) {
      if (pack.id == id) return pack;
    }
    for (final pack in customPacks) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  ThemeState copyWith({
    ThemeAppearance? appearance,
    Brightness? platformBrightness,
  }) =>
      ThemeState(
        appearance: appearance ?? this.appearance,
        platformBrightness: platformBrightness ?? this.platformBrightness,
      );
}

final themeProvider =
    StateNotifierProvider<ThemeAppearanceNotifier, ThemeState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeAppearanceNotifier(prefs);
});

/// Convenience: current [ThemeData].
final activeThemeDataProvider = Provider<ThemeData>((ref) {
  return ref.watch(themeProvider).themeData;
});

/// Convenience: effective dark mode.
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isEffectivelyDark;
});

class ThemeAppearanceNotifier extends StateNotifier<ThemeState> {
  ThemeAppearanceNotifier(this._prefs)
      : super(
          ThemeState(
            appearance: ThemeAppearance.defaults,
            platformBrightness:
                SchedulerBinding.instance.platformDispatcher.platformBrightness,
          ),
        ) {
    _load();
  }

  final SharedPreferences _prefs;
  Timer? _pendingSave;
  var _nextCustomSeq = 1;

  void _load() {
    final raw = _prefs.getString(_themeAppearanceKey);
    if (raw == null) return;
    try {
      final appearance =
          ThemeAppearance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _nextCustomSeq = _deriveNextCustomSeq(appearance.customPacks);
      state = state.copyWith(appearance: appearance);
    } catch (_) {
      // Keep defaults if persisted payload is corrupt.
    }
  }

  int _deriveNextCustomSeq(List<ThemeColorPack> packs) {
    var max = 0;
    for (final pack in packs) {
      final match = RegExp(r'^custom_(\d+)$').firstMatch(pack.id);
      if (match != null) {
        max = math.max(max, int.parse(match.group(1)!));
      }
    }
    return max + 1;
  }

  void _scheduleSave() {
    _pendingSave?.cancel();
    _pendingSave = Timer(const Duration(milliseconds: 250), _save);
  }

  Future<void> _save() async {
    await _prefs.setString(
      _themeAppearanceKey,
      jsonEncode(state.appearance.toJson()),
    );
  }

  void syncPlatformBrightness(Brightness brightness) {
    if (state.platformBrightness == brightness) return;
    state = state.copyWith(platformBrightness: brightness);
  }

  void setThemeMode(AppThemeMode mode) {
    if (state.themeMode == mode) return;
    state = state.copyWith(
      appearance: state.appearance.copyWith(mode: mode),
    );
    _scheduleSave();
  }

  void updateToken(ThemeToken token, int value) {
    final appearance = state.appearance;
    if (state.isEffectivelyDark) {
      state = state.copyWith(
        appearance: appearance.copyWith(
          darkTokens: appearance.darkTokens.withValue(token, value),
        ),
      );
    } else {
      state = state.copyWith(
        appearance: appearance.copyWith(
          lightTokens: appearance.lightTokens.withValue(token, value),
        ),
      );
    }
    _scheduleSave();
  }

  void applyPack(String packId) {
    final pack = state.packById(packId);
    if (pack == null) return;
    final appearance = state.appearance;
    if (state.isEffectivelyDark) {
      state = state.copyWith(
        appearance: appearance.copyWith(
          darkTokens: pack.tokens,
          darkPackId: pack.id,
        ),
      );
    } else {
      state = state.copyWith(
        appearance: appearance.copyWith(
          lightTokens: pack.tokens,
          lightPackId: pack.id,
        ),
      );
    }
    _scheduleSave();
  }

  void restoreDefaults() {
    final pack = state.activePack;
    if (pack == null) return;
    applyPack(pack.id);
  }

  int nextDefaultThemeNumber() {
    final pattern = RegExp(r'^(?:主题|Theme)\s*(\d+)$', caseSensitive: false);
    var max = 0;
    for (final pack in state.customPacks) {
      final match = pattern.firstMatch(pack.name.trim());
      if (match != null) {
        max = math.max(max, int.parse(match.group(1)!));
      }
    }
    return max + 1;
  }

  void saveCurrentAsTheme(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final pack = _createCustomPack(name: trimmed, tokens: state.tokens);
    final packs = [...state.customPacks, pack];
    final appearance = state.appearance.copyWith(customPacks: packs);
    state = state.copyWith(
      appearance: state.isEffectivelyDark
          ? appearance.copyWith(darkPackId: pack.id)
          : appearance.copyWith(lightPackId: pack.id),
    );
    _scheduleSave();
  }

  void renameCustomPack(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = state.customPacks.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final packs = List<ThemeColorPack>.of(state.customPacks);
    packs[index] = packs[index].copyWith(name: trimmed);
    state = state.copyWith(
      appearance: state.appearance.copyWith(customPacks: packs),
    );
    _scheduleSave();
  }

  void copyCustomPack(String id, String name) {
    final source = state.customPacks.where((p) => p.id == id).firstOrNull;
    final trimmed = name.trim();
    if (source == null || trimmed.isEmpty) return;
    final pack = _createCustomPack(name: trimmed, tokens: source.tokens);
    state = state.copyWith(
      appearance: state.appearance.copyWith(
        customPacks: [...state.customPacks, pack],
      ),
    );
    _scheduleSave();
  }

  void deleteCustomPack(String id) {
    if (!state.customPacks.any((p) => p.id == id)) return;
    var appearance = state.appearance.copyWith(
      customPacks: [
        for (final pack in state.customPacks)
          if (pack.id != id) pack,
      ],
    );
    if (appearance.lightPackId == id) {
      appearance = appearance.copyWith(
        lightPackId: ThemeColorPack.builtInId(ThemePreset.light),
        lightTokens: ThemeTokens.presets[ThemePreset.light]!,
      );
    }
    if (appearance.darkPackId == id) {
      appearance = appearance.copyWith(
        darkPackId: ThemeColorPack.builtInId(ThemePreset.darkModern),
        darkTokens: ThemeTokens.defaults,
      );
    }
    state = state.copyWith(appearance: appearance);
    _scheduleSave();
  }

  ThemeColorPack _createCustomPack({
    required String name,
    required ThemeTokens tokens,
  }) {
    final id = 'custom_$_nextCustomSeq';
    _nextCustomSeq += 1;
    return ThemeColorPack(id: id, name: name, tokens: tokens);
  }

  void updateUi(UiPreferences ui) {
    state = state.copyWith(
      appearance: state.appearance.copyWith(ui: ui),
    );
    _scheduleSave();
  }

  void updateFontSize(double value) =>
      updateUi(state.ui.copyWith(fontSize: value));

  void updateFontFamilyId(String id) =>
      updateUi(state.ui.copyWith(fontFamilyId: id));

  void updateCornerRadius(double value) =>
      updateUi(state.ui.copyWith(cornerRadius: value));

  void updateBarCornerRadius(double value) =>
      updateUi(state.ui.copyWith(barCornerRadius: value));

  void updateChatBubbleCornerRadius(double value) =>
      updateUi(state.ui.copyWith(chatBubbleCornerRadius: value));

  void updateShowBorders(bool value) =>
      updateUi(state.ui.copyWith(showBorders: value));

  @override
  void dispose() {
    _pendingSave?.cancel();
    super.dispose();
  }
}
