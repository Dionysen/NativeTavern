import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/cfg_scale.dart';

void main() {
  group('CFGScaleSettings.getEffectiveSettings', () {
    test('stays inactive while CFG is off', () {
      const settings = CFGScaleSettings(
        enabled: false,
        globalGuidanceScale: 4,
        globalNegativePrompt: 'blur',
      );

      final effective = settings.getEffectiveSettings(characterId: 'hero');
      expect(effective.isActive, isFalse);
      expect(effective.guidanceScale, 1);
      expect(effective.negativePrompt, isEmpty);
    });

    test('character settings override globals, and chat settings win', () {
      const settings = CFGScaleSettings(
        enabled: true,
        globalGuidanceScale: 1.2,
        globalNegativePrompt: 'global',
        characterSettings: [
          CharacterCFGSettings(
            characterId: 'hero',
            useCharacterSettings: true,
            guidanceScale: 2.5,
            negativePrompt: 'character',
          ),
        ],
      );

      final character = settings.getEffectiveSettings(characterId: 'hero');
      expect(character.guidanceScale, 2.5);
      expect(character.negativePrompt, 'character');
      expect(character.isActive, isTrue);

      final other = settings.getEffectiveSettings(characterId: 'npc');
      expect(other.guidanceScale, 1.2);
      expect(other.negativePrompt, 'global');

      final chat = settings.getEffectiveSettings(
        characterId: 'hero',
        chatSettings: const ChatCFGSettings(
          guidanceScale: 3,
          negativePrompt: 'chat',
        ),
      );
      expect(chat.guidanceScale, 3);
      expect(chat.negativePrompt, 'chat');
    });

    test('serialize round-trips character overrides', () {
      const settings = CFGScaleSettings(
        enabled: true,
        globalGuidanceScale: 1.4,
        characterSettings: [
          CharacterCFGSettings(
            characterId: 'hero',
            useCharacterSettings: true,
            positivePrompt: 'sharp',
          ),
        ],
      );

      final restored = CFGScaleSettings.deserialize(
        CFGScaleSettings.serialize(settings),
      );
      expect(restored.enabled, isTrue);
      expect(restored.globalGuidanceScale, 1.4);
      expect(restored.characterSettings.single.positivePrompt, 'sharp');
    });
  });
}
