import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/theme/theme_tokens.dart';
import 'package:native_tavern/data/models/theme/ui_preferences.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

void main() {
  group('ThemeTokens chat defaults', () {
    test('built-in packs derive chat colors from chrome tokens', () {
      final dark = ThemeTokens.defaults;
      expect(dark.chatBackground, dark.editorSurface);
      expect(dark.characterBubble, dark.controlSurface);
      expect(dark.chatText, dark.primaryText);
      expect(dark.dialogueText, dark.tertiaryAccent);
      expect(dark.dialogueText, isNot(dark.chatText));
      expect(dark.userBubble, isNot(dark.editorSurface));

      final light = ThemeTokens.presets[ThemePreset.light]!;
      expect(light.dialogueText, light.tertiaryAccent);
      expect(light.chatBackground, light.editorSurface);
    });

    test('fromJson backfills missing chat tokens', () {
      final tokens = ThemeTokens.fromJson({
        'editorSurface': 0xFF111111,
        'sidebarSurface': 0xFF101010,
        'controlSurface': 0xFF222222,
        'border': 0xFF333333,
        'divider': 0xFF333333,
        'primaryText': 0xFFEEEEEE,
        'mutedText': 0xFFAAAAAA,
        'accent': 0xFF3376CE,
        'cursor': 0xFFFFFFFF,
      });
      expect(tokens.chatBackground, 0xFF111111);
      expect(tokens.characterBubble, 0xFF222222);
      expect(tokens.chatText, 0xFFEEEEEE);
      expect(tokens.dialogueText, ThemeTokens.defaultTertiaryAccent);
    });
  });

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

    test('exposes AppChatColors from tokens', () {
      final theme = buildNativeTavernTheme(ThemeTokens.defaults);
      final chat = theme.extension<AppChatColors>();
      expect(chat, isNotNull);
      expect(chat!.dialogueText, isNot(chat.chatText));
      expect(chat.dialogueText.toARGB32(), ThemeTokens.defaults.dialogueText);
      expect(chat.chatBackground.toARGB32(), ThemeTokens.defaults.chatBackground);
    });
  });
}
