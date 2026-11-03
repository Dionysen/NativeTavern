import 'app_theme_mode.dart';
import 'theme_color_pack.dart';
import 'theme_tokens.dart';
import 'ui_preferences.dart';

/// Persisted appearance: mode, light/dark token slots, custom packs, chrome.
class ThemeAppearance {
  const ThemeAppearance({
    required this.mode,
    required this.lightTokens,
    required this.darkTokens,
    required this.lightPackId,
    required this.darkPackId,
    required this.customPacks,
    required this.ui,
  });

  static ThemeAppearance get defaults => ThemeAppearance(
        mode: AppThemeMode.system,
        lightTokens: ThemeTokens.presets[ThemePreset.light]!,
        darkTokens: ThemeTokens.defaults,
        lightPackId: ThemeColorPack.builtInId(ThemePreset.light),
        darkPackId: ThemeColorPack.builtInId(ThemePreset.darkModern),
        customPacks: const [],
        ui: UiPreferences.defaults,
      );

  final AppThemeMode mode;
  final ThemeTokens lightTokens;
  final ThemeTokens darkTokens;
  final String lightPackId;
  final String darkPackId;
  final List<ThemeColorPack> customPacks;
  final UiPreferences ui;

  ThemeAppearance copyWith({
    AppThemeMode? mode,
    ThemeTokens? lightTokens,
    ThemeTokens? darkTokens,
    String? lightPackId,
    String? darkPackId,
    List<ThemeColorPack>? customPacks,
    UiPreferences? ui,
  }) =>
      ThemeAppearance(
        mode: mode ?? this.mode,
        lightTokens: lightTokens ?? this.lightTokens,
        darkTokens: darkTokens ?? this.darkTokens,
        lightPackId: lightPackId ?? this.lightPackId,
        darkPackId: darkPackId ?? this.darkPackId,
        customPacks: customPacks ?? this.customPacks,
        ui: ui ?? this.ui,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.storageValue,
        'lightTokens': lightTokens.toJson(),
        'darkTokens': darkTokens.toJson(),
        'lightPackId': lightPackId,
        'darkPackId': darkPackId,
        'customPacks': customPacks.map((p) => p.toJson()).toList(),
        'ui': ui.toJson(),
      };

  factory ThemeAppearance.fromJson(Map<String, dynamic> json) {
    final custom = (json['customPacks'] as List<dynamic>? ?? const [])
        .map((e) => ThemeColorPack.fromJson(e as Map<String, dynamic>))
        .toList();
    return ThemeAppearance(
      mode: AppThemeMode.fromStorage(json['mode'] as String?),
      lightTokens: json['lightTokens'] is Map<String, dynamic>
          ? ThemeTokens.fromJson(json['lightTokens'] as Map<String, dynamic>)
          : ThemeTokens.presets[ThemePreset.light]!,
      darkTokens: json['darkTokens'] is Map<String, dynamic>
          ? ThemeTokens.fromJson(json['darkTokens'] as Map<String, dynamic>)
          : ThemeTokens.defaults,
      lightPackId: json['lightPackId'] as String? ??
          ThemeColorPack.builtInId(ThemePreset.light),
      darkPackId: json['darkPackId'] as String? ??
          ThemeColorPack.builtInId(ThemePreset.darkModern),
      customPacks: custom,
      ui: UiPreferences.fromJson(json['ui'] as Map<String, dynamic>?),
    );
  }
}
