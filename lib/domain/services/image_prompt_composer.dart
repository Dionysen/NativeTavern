/// Builds / assembles image prompts in the SillyTavern scene style:
/// quality prefix + LLM Danbooru tags + fixed appearance prefixes.
class ImagePromptComposer {
  static const _maxFallbackLength = 400;

  static const defaultCommonPrefix =
      'masterpiece, best quality, very awa, absurdres, anime style, {prompt}, rating:explicit';

  static const defaultNegativePrompt =
      'worst quality, low quality, lowres, bad hands, mutated hands, extra digits, '
      'bad anatomy, signature, username, watermark, character fusion, face merge, '
      'fused faces, censored, mosaic censoring, text, logo, multiple views';

  static const defaultLlmInstruction =
      'Convert the latest chat moment into ONE line of Danbooru tags for anime image generation.\n'
      'Include: subject count (1boy, 1girl), action/pose, expression, clothing state, location, lighting.\n'
      'Do NOT write full English sentences. Do NOT explain. Do NOT repeat fixed appearance tags.\n'
      'For NSFW use explicit action tags (kissing, sex, vaginal, doggy style, missionary, etc.).\n'
      'Output tags only, comma-separated.';

  const ImagePromptComposer();

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
    // Prefer tag-like fallback; keep short.
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
          'Scene:',
          scene.isEmpty ? '(empty)' : scene,
        ].join('\n'),
      },
    ];
  }

  /// Final ComfyUI / SD prompt:
  /// `[common prefix with {prompt}]` where prompt =
  /// `sceneTags, characterAppearance, personaAppearance`.
  String assembleFinalPrompt({
    required String sceneTags,
    String? commonPrefix,
    String? characterAppearance,
    String? personaAppearance,
  }) {
    final parts = <String>[
      sceneTags.trim(),
      (characterAppearance ?? '').trim(),
      (personaAppearance ?? '').trim(),
    ].where((part) => part.isNotEmpty).toList();
    final body = parts.join(', ');
    final prefix = (commonPrefix == null || commonPrefix.trim().isEmpty)
        ? defaultCommonPrefix
        : commonPrefix.trim();
    if (body.isEmpty) {
      return prefix.contains('{prompt}')
          ? prefix.replaceAll('{prompt}', '').replaceAll(RegExp(r',\s*,'), ',').trim()
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
    text = text.replaceAll('"', '').trim();
    // Keep first line only — models sometimes add explanations.
    final lineBreak = text.indexOf('\n');
    if (lineBreak > 0) {
      text = text.substring(0, lineBreak).trim();
    }
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
