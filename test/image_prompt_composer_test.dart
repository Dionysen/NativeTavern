import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/image_prompt_composer.dart';
import 'package:native_tavern/domain/services/llm_service.dart';

void main() {
  const composer = ImagePromptComposer();

  test('fallback prompt keeps a short tag-like scene', () {
    expect(
      composer.fallbackPrompt(
        sceneText: '<p>She  opens the lantern.</p>',
        characterName: 'Mira',
      ),
      'She opens the lantern.',
    );
  });

  test('compose messages ask for a core-scene Danbooru line', () {
    final messages = composer.composeMessages(
      sceneText: 'A rainy harbor at dusk',
      characterName: 'Mira',
      characterAppearance: '1girl, silver hair',
      personaAppearance: '1boy, black hair',
    );

    expect(messages, hasLength(2));
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], contains('most important'));
    expect(messages.first['content'], contains('Do NOT invent hair'));
    expect(messages.last['content'], contains('Mira'));
    expect(messages.last['content'], contains('1girl, silver hair'));
    expect(messages.last['content'], contains('most important visual moment'));
    expect(messages.last['content'], contains('A rainy harbor at dusk'));
  });

  test('assembleFinalPrompt wraps scene with beauty boost and appearances', () {
    final prompt = composer.assembleFinalPrompt(
      sceneTags: '1boy, 1girl, kissing, bedroom',
      commonPrefix:
          'masterpiece, best quality, {prompt}, rating:explicit',
      characterAppearance: '1girl, silver hair, blue eyes',
      personaAppearance: '1boy, short black hair',
    );

    expect(prompt, contains('1boy, 1girl, kissing, bedroom'));
    expect(prompt, contains('beautiful face'));
    expect(prompt, contains('perfect body'));
    expect(prompt, contains('1girl, silver hair, blue eyes'));
    expect(prompt, contains('1boy, short black hair'));
    expect(prompt, startsWith('masterpiece, best quality,'));
    expect(prompt, endsWith('rating:explicit'));
  });

  test('normalizeModelOutput strips fences, think blocks, keeps first line', () {
    expect(
      composer.normalizeModelOutput(
        '```text\n"1girl, sitting, cafe"\nextra note\n```',
      ),
      '1girl, sitting, cafe',
    );
    expect(
      composer.normalizeModelOutput(
        '<think>plan…</think>\n1girl, standing, park',
      ),
      '1girl, standing, park',
    );
  });

  test('llmConfigForCompose disables extended thinking and caps tokens', () {
    const base = LLMConfig(
      provider: LLMProvider.openai,
      model: 'gpt-test',
      apiKey: 'k',
      apiUrl: 'https://example.com/v1',
      reasoningEffort: ReasoningEffort.high,
      maxTokens: 8192,
      temperature: 1.0,
      streamEnabled: true,
    );
    final tuned = ImagePromptComposer.llmConfigForCompose(base);
    expect(tuned.reasoningEffort, ReasoningEffort.auto);
    expect(tuned.maxTokens, 256);
    expect(tuned.temperature, 0.3);
    expect(tuned.streamEnabled, isFalse);
  });
}
