import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/ai_preset.dart';
import 'package:native_tavern/data/models/prompt_manager.dart';

void main() {
  group('PromptManagerConfig CRUD', () {
    test('addCustomSection appends enabled custom entry', () {
      final config = PromptManagerConfig.defaultConfig().addCustomSection(
        name: 'My Prompt',
        identifier: 'custom-1',
        content: 'Hello {{char}}',
      );

      final custom = config.sections.where((s) => s.isCustom).toList();
      expect(custom, hasLength(1));
      expect(custom.first.name, 'My Prompt');
      expect(custom.first.identifier, 'custom-1');
      expect(custom.first.enabled, isTrue);
      expect(custom.first.content, 'Hello {{char}}');
    });

    test('removeSectionAt only removes custom sections', () {
      var config = PromptManagerConfig.defaultConfig().addCustomSection(
        name: 'Temp',
        identifier: 'temp-id',
        content: 'x',
      );
      final customIndex =
          config.sortedSections.indexWhere((s) => s.identifier == 'temp-id');
      expect(customIndex, greaterThanOrEqualTo(0));

      final withoutCustom = config.removeSectionAt(customIndex);
      expect(withoutCustom.sections.any((s) => s.identifier == 'temp-id'),
          isFalse);

      // Built-in index 0 cannot be removed
      final unchanged = withoutCustom.removeSectionAt(0);
      expect(unchanged.sections.length, withoutCustom.sections.length);
    });

    test('duplicateSectionAt clones into a new custom entry', () {
      final base = PromptManagerConfig.defaultConfig();
      final systemIndex = base.sortedSections
          .indexWhere((s) => s.type == PromptSectionType.systemPrompt);
      final duplicated = base.duplicateSectionAt(
        systemIndex,
        newIdentifier: 'dup-1',
        copySuffix: ' 副本',
      );

      final copy = duplicated.sections.firstWhere((s) => s.identifier == 'dup-1');
      expect(copy.isCustom, isTrue);
      expect(copy.name, endsWith(' 副本'));
      expect(copy.content, isNotEmpty);
    });
  });

  group('SillyTavern import/export round-trip', () {
    test('fromSillyTavernJson preserves custom prompts and order', () {
      final json = {
        'prompts': [
          {
            'identifier': 'main',
            'name': 'Main Prompt',
            'content': 'System text',
            'role': 'system',
          },
          {
            'identifier': 'abc-custom',
            'name': 'Extra Lore',
            'content': 'Lore content',
            'role': 'system',
          },
        ],
        'prompt_order': [
          {
            'character_id': 100000,
            'order': [
              {'identifier': 'main', 'enabled': true},
              {'identifier': 'abc-custom', 'enabled': false},
              {'identifier': 'chatHistory', 'enabled': true},
            ],
          },
        ],
      };

      final config = PromptManagerConfig.fromSillyTavernJson(json);
      final sorted = config.sortedSections;

      expect(sorted.first.identifier, 'main');
      expect(sorted.first.content, 'System text');

      final custom =
          sorted.firstWhere((s) => s.identifier == 'abc-custom');
      expect(custom.isCustom, isTrue);
      expect(custom.enabled, isFalse);
      expect(custom.content, 'Lore content');
    });

    test('AIPreset export includes prompts array with stable identifiers', () {
      final promptConfig =
          PromptManagerConfig.defaultConfig().addCustomSection(
        name: 'Extra',
        identifier: 'stable-custom-id',
        content: 'Extra body',
      );
      final preset = AIPreset(
        id: 'p1',
        name: 'Test',
        isBuiltIn: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        generationSettings: const GenerationPreset(),
        promptManagerConfig: promptConfig,
      );

      final exported = preset.toExportJson();
      expect(exported.containsKey('prompts'), isTrue);
      expect(exported.containsKey('prompt_order'), isTrue);

      final prompts = exported['prompts'] as List<dynamic>;
      final custom = prompts.cast<Map<String, dynamic>>().firstWhere(
            (p) => p['identifier'] == 'stable-custom-id',
          );
      expect(custom['content'], 'Extra body');
      expect(custom['name'], 'Extra');

      final order = ((exported['prompt_order'] as List).first
          as Map<String, dynamic>)['order'] as List<dynamic>;
      expect(
        order.any((e) =>
            (e as Map)['identifier'] == 'stable-custom-id' &&
            e['enabled'] == true),
        isTrue,
      );

      final roundTrip = PromptManagerConfig.fromSillyTavernJson(exported);
      final restored = roundTrip.sections
          .firstWhere((s) => s.identifier == 'stable-custom-id');
      expect(restored.content, 'Extra body');
      expect(restored.name, 'Extra');
    });
  });
}
