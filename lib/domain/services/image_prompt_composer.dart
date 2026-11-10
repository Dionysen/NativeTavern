import 'package:native_tavern/domain/services/llm_service.dart';

/// Builds / assembles image prompts in the SillyTavern scene style:
/// quality prefix + LLM Danbooru tags + fixed beauty / appearance prefixes.
class ImagePromptComposer {
  static const _maxFallbackLength = 400;

  static const defaultCommonPrefix =
      'masterpiece, best quality, very awa, absurdres, anime style, {prompt}, rating:explicit';

  /// Always-on beauty / body polish tags (appended after the scene tags).
  static const defaultBeautyBoost =
      'beautiful face, perfect face, detailed eyes, pretty face, gorgeous, '
      'perfect body, beautiful proportions, attractive figure, soft skin, '
      'elegant posture';

  static const defaultNegativePrompt =
      'worst quality, low quality, lowres, bad hands, mutated hands, extra digits, '
      'bad anatomy, ugly, deformed, disfigured, asymmetric eyes, signature, username, '
      'watermark, character fusion, face merge, fused faces, censored, mosaic censoring, '
      'text, logo, multiple views';

  /// Instructs a fast non-thinking pass: core scene only, tags only.
  static const defaultLlmInstruction =
      'You turn ONE character reply into a single line of Danbooru tags for anime image generation.\n'
      'Task: summarize only the most important, most representative visual moment in that reply — '
      'the core scene the viewer should see — not every detail of the text.\n'
      'Extract the strongest visual features of that moment: subject count (1girl, 1boy, …), '
      'main pose/action, key expression, clothing or body state that matters, location, lighting.\n'
      'Ignore side chatter, minor narration, and anything that is not visually central.\n'
      'Do NOT invent hair, eyes, body type, or outfit details that the system will add separately.\n'
      'Do NOT write sentences, lists of steps, explanations, or chain-of-thought.\n'
      'For NSFW, use direct action tags for the core moment (kissing, sex, vaginal, doggy style, …).\n'
      'Output ONLY comma-separated Danbooru tags on one line.';

  const ImagePromptComposer();

  /// LLM settings for prompt tagging: short answer, no extended thinking.
  static LLMConfig llmConfigForCompose(LLMConfig base) {
    return base.copyWith(
      // auto = do not enable Claude/Gemini extended thinking blocks
      reasoningEffort: ReasoningEffort.auto,
      maxTokens: 256,
      temperature: 0.3,
      streamEnabled: false,
    );
  }

  String fallbackPrompt({
    required String sceneText,
    String? characterName,
  }) {
    final cleaned = _cleanScene(sceneText);
    final subject = characterName?.trim();
    if (cleaned.isEmpty) {
      return subject == null || subject.isEmpty
          ? ''
          : '1girl, solo, looking at viewer, $subject';
    }
    if (subject == null || subject.isEmpty) return cleaned;
    return cleaned;
  }

  List<Map<String, dynamic>> composeMessages({
    required String sceneText,
    String? characterName,
    String? instruction,
    String? characterAppearance,
    String? personaAppearance,
  }) {
    final scene = _cleanScene(sceneText);
    final subject = characterName?.trim();
    final subjectLine = subject == null || subject.isEmpty
        ? 'No named subject.'
        : 'Character name (do not invent appearance): $subject';
    final appearanceBits = <String>[
      if ((characterAppearance ?? '').trim().isNotEmpty)
        'Character appearance is provided by the system (do not repeat): ${characterAppearance!.trim()}',
      if ((personaAppearance ?? '').trim().isNotEmpty)
        'User/persona appearance is provided by the system (do not repeat): ${personaAppearance!.trim()}',
    ];
    final system = (instruction == null || instruction.trim().isEmpty)
        ? defaultLlmInstruction
        : instruction.trim();
    return [
      {
        'role': 'system',
        'content': system,
      },
      {
        'role': 'user',
        'content': [
          subjectLine,
          ...appearanceBits,
          'Summarize the single most important visual moment in this reply:',
          scene.isEmpty ? '(empty)' : scene,
        ].join('\n'),
      },
    ];
  }

  /// Final ComfyUI / SD prompt:
  /// `[common prefix with {prompt}]` where prompt =
  /// `sceneTags, beautyBoost, characterAppearance, personaAppearance`.
  String assembleFinalPrompt({
    required String sceneTags,
    String? commonPrefix,
    String? characterAppearance,
    String? personaAppearance,
    String? beautyBoost,
  }) {
    final beauty = (beautyBoost == null || beautyBoost.trim().isEmpty)
        ? defaultBeautyBoost
        : beautyBoost.trim();
    final parts = <String>[
      sceneTags.trim(),
      beauty,
      (characterAppearance ?? '').trim(),
      (personaAppearance ?? '').trim(),
    ].where((part) => part.isNotEmpty).toList();
    final body = parts.join(', ');
    final prefix = (commonPrefix == null || commonPrefix.trim().isEmpty)
        ? defaultCommonPrefix
        : commonPrefix.trim();
    if (body.isEmpty) {
      return prefix.contains('{prompt}')
          ? prefix
              .replaceAll('{prompt}', '')
              .replaceAll(RegExp(r',\s*,'), ',')
              .trim()
          : prefix;
    }
    if (prefix.contains('{prompt}')) {
      return prefix.replaceAll('{prompt}', body);
    }
    return '$prefix, $body';
  }

  String normalizeModelOutput(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'\n?```$'), '');
    }
    // Drop leaked think / reasoning blocks from non-compliant endpoints.
    text = text.replaceAll(
      RegExp(
        r'<(think|thinking|thought|reasoning)>[\s\S]*?</\1>',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll('"', '').trim();
    // Keep first non-empty line — models sometimes add explanations.
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    text = lines.isEmpty ? '' : lines.first;
    return text;
  }

  String _cleanScene(String sceneText) {
    var text = sceneText.trim();
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= _maxFallbackLength) return text;
    return text.substring(0, _maxFallbackLength).trim();
  }
}
