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
    expect(messages.first['content'], contains('at most 20'));
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
    // Duplicate subject tags are deduped; appearance traits still land.
    expect(prompt, contains('silver hair'));
    expect(prompt, contains('blue eyes'));
    expect(prompt, contains('short black hair'));
    expect(prompt, startsWith('masterpiece, best quality,'));
    expect(prompt, endsWith('rating:explicit'));
    expect(
      ImagePromptComposer.estimateClipTokens(prompt),
      lessThanOrEqualTo(ImagePromptComposer.maxPromptTokens),
    );
  });

  test('assembleFinalPrompt stays within 75 CLIP tokens', () {
    final prompt = composer.assembleFinalPrompt(
      sceneTags: List.generate(40, (i) => 'scene_tag_$i').join(', '),
      characterAppearance:
          'long silver hair, blue eyes, school uniform, red ribbon',
      personaAppearance: 'short black hair, jacket, tall',
      beautyBoost:
          'beautiful face, detailed eyes, perfect body, soft skin, elegant posture',
    );

    expect(
      ImagePromptComposer.estimateClipTokens(prompt),
      lessThanOrEqualTo(75),
    );
    // Section budgets keep some scene and appearance under the hard cap.
    expect(prompt, contains('scene_tag_0'));
    expect(prompt, contains('silver hair'));
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
    expect(tuned.maxTokens, 96);
    expect(tuned.temperature, 0.3);
    expect(tuned.streamEnabled, isFalse);
  });
}
