import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/theme/theme_tokens.dart';
import 'package:native_tavern/data/models/theme/ui_preferences.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

void main() {
  group('buildNativeTavernTheme', () {
    test('tooltip and chrome text styles use configured font family', () {
      const family = 'CustomUiFont';
      final theme = buildNativeTavernTheme(
        ThemeTokens.defaults,
        ui: UiPreferences.defaults.copyWith(fontFamily: family),
      );

      expect(theme.textTheme.bodyMedium?.fontFamily, family);
      expect(theme.tooltipTheme.textStyle?.fontFamily, family);
      expect(theme.inputDecorationTheme.hintStyle?.fontFamily, family);
      expect(theme.snackBarTheme.contentTextStyle?.fontFamily, family);
    });
  });
}
