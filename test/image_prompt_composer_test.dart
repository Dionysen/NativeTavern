import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/image_prompt_composer.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/domain/skills/noobai_danbooru_prompt_skill.dart';

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

  test('compose messages load NoobAI Danbooru skill instruction', () {
    final messages = composer.composeMessages(
      sceneText: 'A rainy harbor at dusk',
      characterName: 'Mira',
      characterAppearance: '1girl, silver hair',
      personaAppearance: '1boy, black hair',
    );

    expect(messages, hasLength(2));
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], contains('Danbooru'));
    expect(messages.first['content'], contains('18-32 tags'));
    expect(messages.first['content'], contains('NSFW / SFW'));
    expect(messages.first['content'], contains('face-visible'));
    expect(messages.last['content'], contains(NoobaiDanbooruPromptSkill.id));
    expect(messages.last['content'], contains('Mira'));
    expect(messages.last['content'], contains('1girl, silver hair'));
    expect(messages.last['content'], contains('Scene:'));
    expect(messages.last['content'], contains('A rainy harbor at dusk'));
  });

  test('assembleFinalPrompt uses dynamic safe rating for clothed scenes', () {
    final prompt = composer.assembleFinalPrompt(
      sceneTags: '1boy, solo, standing, grey jacket, office, window_light',
      characterAppearance: '1boy, short black hair, brown eyes',
    );

    expect(prompt, contains('1boy'));
    expect(prompt, contains('grey jacket'));
    expect(prompt, contains('short black hair'));
    expect(prompt, contains('very awa'));
    expect(prompt, contains('absurdres'));
    expect(prompt, isNot(contains('beautiful face')));
    expect(prompt, endsWith('rating:safe'));
    expect(
      ImagePromptComposer.estimateClipTokens(prompt),
      lessThanOrEqualTo(ImagePromptComposer.maxPromptTokens),
    );
  });

  test('assembleFinalPrompt uses explicit rating for NSFW scene tags', () {
    final prompt = composer.assembleFinalPrompt(
      sceneTags: '1boy, 1girl, hetero, sex, nude, vaginal, on bed, bedroom',
      commonPrefix:
          'masterpiece, best quality, very awa, {prompt}, {rating}',
      characterAppearance: '1girl, silver hair, blue eyes',
      personaAppearance: '1boy, short black hair',
    );

    expect(prompt, contains('sex'));
    expect(prompt, contains('silver hair'));
    expect(prompt, contains('short black hair'));
    expect(prompt, endsWith('rating:explicit'));
    expect(
      ImagePromptComposer.estimateClipTokens(prompt),
      lessThanOrEqualTo(ImagePromptComposer.maxPromptTokens),
    );
  });

  test('assembleFinalPrompt stays within SDXL token budget', () {
    final prompt = composer.assembleFinalPrompt(
      sceneTags: List.generate(40, (i) => 'scene_tag_$i').join(', '),
      characterAppearance:
          'long silver hair, blue eyes, school uniform, red ribbon',
      personaAppearance: 'short black hair, jacket, tall',
    );

    expect(
      ImagePromptComposer.estimateClipTokens(prompt),
      lessThanOrEqualTo(ImagePromptComposer.maxPromptTokens),
    );
    expect(prompt, contains('scene_tag_0'));
    expect(prompt, contains('silver hair'));
  });

  test('skill resolves rating from markers', () {
    expect(
      NoobaiDanbooruPromptSkill.resolveRatingTag('1girl, grey jacket, office'),
      'rating:safe',
    );
    expect(
      NoobaiDanbooruPromptSkill.resolveRatingTag('1girl, lingerie, cleavage'),
      'rating:questionable',
    );
    expect(
      NoobaiDanbooruPromptSkill.resolveRatingTag('1girl, nude, pussy'),
      'rating:explicit',
    );
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

  test('llmConfigForCompose keeps user model settings, disables stream only', () {
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
    expect(tuned.reasoningEffort, ReasoningEffort.high);
    expect(tuned.maxTokens, 8192);
    expect(tuned.temperature, 1.0);
    expect(tuned.model, 'gpt-test');
    expect(tuned.streamEnabled, isFalse);
  });
}
