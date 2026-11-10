import 'package:native_tavern/domain/services/llm_service.dart';

/// Builds / assembles image prompts in the SillyTavern scene style:
/// quality prefix + LLM Danbooru tags + short beauty polish + appearances,
/// capped near the classic CLIP 75-token budget.
class ImagePromptComposer {
  /// Soft CLIP-style budget for the final positive prompt (SD1.5 era).
  static const maxPromptTokens = 75;

  static const _maxFallbackLength = 280;

  static const defaultCommonPrefix =
      'masterpiece, best quality, anime style, {prompt}, rating:explicit';

  /// Short always-on polish — keep tiny so scene/appearance keep the budget.
  static const defaultBeautyBoost =
      'beautiful face, detailed eyes, perfect body';

  static const defaultNegativePrompt =
      'worst quality, low quality, lowres, bad hands, mutated hands, extra digits, '
      'bad anatomy, ugly, deformed, disfigured, asymmetric eyes, signature, username, '
      'watermark, character fusion, face merge, fused faces, censored, mosaic censoring, '
      'text, logo, multiple views';

  static const defaultLlmInstruction =
      'Convert the latest chat moment into ONE line of Danbooru tags for anime image generation.\n'
      'Include: subject count (1boy, 1girl), action/pose, expression, clothing state, location, lighting.\n'
      'Do NOT write full English sentences. Do NOT explain. Do NOT repeat fixed appearance tags.\n'
      'Keep it short: at most 20 comma-separated tags (prefer 8–15).\n'
      'For NSFW use explicit action tags (kissing, sex, vaginal, doggy style, missionary, etc.).\n'
      'Output tags only, comma-separated.';

  const ImagePromptComposer();

  /// Prompt tagging uses the user's LLM settings (model, reasoning, samplers).
  /// Only disable streaming — the compose UI awaits a single completion.
  static LLMConfig llmConfigForCompose(LLMConfig base) {
    return base.copyWith(streamEnabled: false);
  }

  /// Rough CLIP token estimate: underscore/space-separated words.
  static int estimateClipTokens(String text) {
    final normalized = text
        .replaceAll(',', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return 0;
    return normalized.split(' ').length;
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
          'Scene:',
          scene.isEmpty ? '(empty)' : scene,
        ].join('\n'),
      },
    ];
  }

  /// Final ComfyUI / SD prompt, capped to [maxPromptTokens].
  ///
  /// Body is packed in sections so a long scene dump cannot wipe appearance:
  /// scene (~50%) → appearances (~40%) → beauty (remainder).
  String assembleFinalPrompt({
    required String sceneTags,
    String? commonPrefix,
    String? characterAppearance,
    String? personaAppearance,
    String? beautyBoost,
    int maxTokens = maxPromptTokens,
  }) {
    final beauty = (beautyBoost == null || beautyBoost.trim().isEmpty)
        ? defaultBeautyBoost
        : beautyBoost.trim();
    final prefix = (commonPrefix == null || commonPrefix.trim().isEmpty)
        ? defaultCommonPrefix
        : commonPrefix.trim();

    final prefixShellCost = prefix.contains('{prompt}')
        ? estimateClipTokens(prefix.replaceAll('{prompt}', ' '))
        : estimateClipTokens(prefix);
    final bodyBudget =
        (maxTokens - prefixShellCost).clamp(0, maxTokens).toInt();

    final sceneCap = (bodyBudget * 0.5).floor().clamp(0, 40);
    final appearanceCap = (bodyBudget * 0.4).floor().clamp(0, 28);

    final scene = fitTagsToBudget(_splitTags(sceneTags), sceneCap);
    var used = _tokensForTags(scene);
    final taken = {for (final tag in scene) tag.toLowerCase()};

    final appearances = fitTagsToBudget(
      [
        ..._splitTags(characterAppearance ?? ''),
        ..._splitTags(personaAppearance ?? ''),
      ].where((tag) => !taken.contains(tag.toLowerCase())),
      _minInt(appearanceCap, bodyBudget - used),
    );
    taken.addAll(appearances.map((tag) => tag.toLowerCase()));
    used += _tokensForTags(appearances);

    final beautyTags = fitTagsToBudget(
      _splitTags(beauty),
      bodyBudget - used,
    );

    final body = fitTagsToBudget(
      [...scene, ...appearances, ...beautyTags],
      bodyBudget,
    );

    if (body.isEmpty) {
      return fitTagsToBudget(
        _splitTags(prefix.replaceAll('{prompt}', '')),
        maxTokens,
      ).join(', ');
    }
    final assembled = prefix.contains('{prompt}')
        ? prefix.replaceAll('{prompt}', body.join(', '))
        : '${_splitTags(prefix).join(', ')}, ${body.join(', ')}';
    return fitTagsToBudget(_splitTags(assembled), maxTokens).join(', ');
  }

  static int _tokensForTags(List<String> tags) =>
      estimateClipTokens(tags.join(', '));

  static int _minInt(int a, int b) => a < b ? a : b;

  /// Keeps tags in order until the CLIP-style budget is exhausted; dedupes.
  static List<String> fitTagsToBudget(Iterable<String> tags, int maxTokens) {
    if (maxTokens <= 0) return const [];
    final kept = <String>[];
    final seen = <String>{};
    var used = 0;
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      final key = tag.toLowerCase();
      if (seen.contains(key)) continue;
      final cost = estimateClipTokens(tag);
      if (cost <= 0) continue;
      if (used + cost > maxTokens) continue;
      seen.add(key);
      kept.add(tag);
      used += cost;
    }
    return kept;
  }

  List<String> _splitTags(String text) {
    return text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
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
    // Soft-cap verbose model dumps before final assemble.
    return fitTagsToBudget(_splitTags(text), 40).join(', ');
  }

  String _cleanScene(String sceneText) {
    var text = sceneText.trim();
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= _maxFallbackLength) return text;
    return text.substring(0, _maxFallbackLength).trim();
  }
}
