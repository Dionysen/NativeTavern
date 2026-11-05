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
}
