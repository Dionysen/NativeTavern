import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/image_prompt_composer.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/domain/services/slash_command_service.dart';

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

  test('compose messages ask for Danbooru tags only', () {
    final messages = composer.composeMessages(
      sceneText: 'A rainy harbor at dusk',
      characterName: 'Mira',
      characterAppearance: '1girl, silver hair',
      personaAppearance: '1boy, black hair',
    );

    expect(messages, hasLength(2));
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], contains('Danbooru tags'));
    expect(messages.first['content'], contains('Do NOT repeat fixed appearance'));
    expect(messages.last['content'], contains('Mira'));
    expect(messages.last['content'], contains('1girl, silver hair'));
    expect(messages.last['content'], contains('A rainy harbor at dusk'));
  });

  test('assembleFinalPrompt wraps scene with prefix and appearances', () {
    final prompt = composer.assembleFinalPrompt(
      sceneTags: '1boy, 1girl, kissing, bedroom',
      commonPrefix:
          'masterpiece, best quality, {prompt}, rating:explicit',
      characterAppearance: '1girl, silver hair, blue eyes',
      personaAppearance: '1boy, short black hair',
    );

    expect(
      prompt,
      'masterpiece, best quality, 1boy, 1girl, kissing, bedroom, '
      '1girl, silver hair, blue eyes, 1boy, short black hair, rating:explicit',
    );
  });

  test('normalizeModelOutput strips fences and keeps first line', () {
    expect(
      composer.normalizeModelOutput(
        '```text\n"1girl, sitting, cafe"\nextra note\n```',
      ),
      '1girl, sitting, cafe',
    );
  });

  test('/sd last is accepted as an imagine alias without a free prompt', () {
    final parsed = SlashCommandService().parse('/sd last');
    expect(parsed.command, SlashCommands.imagine);
    expect(parsed.argument, 'last');

    final bare = SlashCommandService().parse('/sd');
    expect(bare.command, SlashCommands.imagine);
    expect(bare.argument, isNull);
  });

  test('/imagine still parses prompt options for the existing chat handler', () {
    final parsed = SlashCommandService().parse(
      '/imagine rainy harbor --width 768 --height 1024',
    );
    expect(parsed.command, SlashCommands.imagine);
    expect(parsed.argument, 'rainy harbor --width 768 --height 1024');

    final request = ImageGenerationService().parseImagineCommand(
      '/imagine rainy harbor --width 768 --height 1024',
    );
    expect(request, isNotNull);
    expect(request!.prompt, 'rainy harbor');
    expect(request.width, 768);
    expect(request.height, 1024);
  });
}
