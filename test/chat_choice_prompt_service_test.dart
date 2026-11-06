import 'package:native_tavern/data/models/chat_choice_config.dart';
import 'package:native_tavern/domain/services/chat_choice_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildSystemPrompt substitutes count, chars, and tendencies', () {
    final config = ChatChoiceConfig(
      choiceCount: 2,
      maxCharsPerChoice: 40,
      slots: const [
        ChatChoiceSlotConfig(tendency: 'bold'),
        ChatChoiceSlotConfig(tendency: ''),
      ],
      promptTemplate:
          'Count={{count}} Max={{max_chars}}\n{{option_lines}}\nT1={{tendency_1}}',
    );
    final prompt = ChatChoicePromptService.buildSystemPrompt(config);
    expect(prompt, contains('Count=2'));
    expect(prompt, contains('Max=40'));
    expect(prompt, contains('Option 1: bold'));
    expect(prompt, contains('Any appropriate direction'));
    expect(prompt, contains('T1=bold'));
  });

  test('parseChoices reads JSON and enforces limits', () {
    const config = ChatChoiceConfig(
      choiceCount: 2,
      maxCharsPerChoice: 12,
    );
    final choices = ChatChoicePromptService.parseChoices(
      '{"choices":["hello world","ok","extra"]}',
      config,
    );
    expect(choices.length, 2);
    expect(choices.first.length, lessThanOrEqualTo(12));
    expect(choices[1], 'ok');
  });

  test('parseChoices accepts bare JSON arrays and fenced JSON', () {
    const config = ChatChoiceConfig(choiceCount: 3, maxCharsPerChoice: 80);
    expect(
      ChatChoicePromptService.parseChoices(
        '["one","two","three"]',
        config,
      ),
      ['one', 'two', 'three'],
    );
    expect(
      ChatChoicePromptService.parseChoices(
        '```json\n{"choices":["a","b","c"]}\n```',
        config,
      ),
      ['a', 'b', 'c'],
    );
  });

  test('parseAndValidate rejects incomplete single-line output', () {
    const config = ChatChoiceConfig(choiceCount: 4, maxCharsPerChoice: 80);
    final result = ChatChoicePromptService.parseAndValidate(
      'Here is a single mashed blob of options without structure.',
      config,
    );
    expect(result.isComplete, isFalse);
    expect(result.choices.length, 1);
    expect(result.validationError, contains('Expected exactly 4'));
  });

  test('parseAndValidate accepts a full JSON payload', () {
    const config = ChatChoiceConfig(choiceCount: 2, maxCharsPerChoice: 80);
    final result = ChatChoicePromptService.parseAndValidate(
      '{"choices":["first reply","second reply"]}',
      config,
    );
    expect(result.isComplete, isTrue);
    expect(result.choices, ['first reply', 'second reply']);
    expect(result.validationError, isNull);
  });

  test('buildFormatRepairPrompt asks for exact JSON shape', () {
    const config = ChatChoiceConfig(choiceCount: 3, maxCharsPerChoice: 40);
    final prompt = ChatChoicePromptService.buildFormatRepairPrompt(
      config: config,
      validationError: 'Expected exactly 3 distinct choices, but got 1.',
    );
    expect(prompt, contains('Expected exactly 3'));
    expect(prompt, contains('"choices"'));
    expect(prompt, contains('exactly 3'));
    expect(prompt, contains('40 characters'));
  });
}
