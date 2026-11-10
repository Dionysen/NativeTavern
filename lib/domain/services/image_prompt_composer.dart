import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/domain/skills/noobai_danbooru_prompt_skill.dart';

/// Builds / assembles image prompts for NoobAI / Illustrious (SDXL-class):
/// quality prefix + LLM Danbooru scene tags + appearances + dynamic rating.
class ImagePromptComposer {
  /// Soft token budget for the final positive prompt (SDXL / NoobAI).
  /// Older SD1.5 CLIP ~75 limit was truncating useful scene detail.
  static const maxPromptTokens = 150;

  static const _maxFallbackLength = 280;

  static const defaultCommonPrefix = NoobaiDanbooruPromptSkill.commonPrefix;

  /// Kept for backward-compatible settings; skill default is empty.
  static const defaultBeautyBoost = NoobaiDanbooruPromptSkill.beautyBoost;

  static const defaultNegativePrompt = NoobaiDanbooruPromptSkill.negativePrompt;

  static const defaultLlmInstruction = NoobaiDanbooruPromptSkill.instruction;

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
          : '1girl, solo, looking_at_viewer, $subject';
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
          'Skill: ${NoobaiDanbooruPromptSkill.id} v${NoobaiDanbooruPromptSkill.version}',
          subjectLine,
          ...appearanceBits,
          'Scene:',
          scene.isEmpty ? '(empty)' : scene,
          'Remember: tags only; match clothing/NSFW to the scene; include subject count + pose + location + lighting.',
        ].join('\n'),
      },
    ];
  }

  /// Final ComfyUI / SD prompt, capped to [maxTokens].
  ///
  /// Body packing: scene (~55%) → appearances (~40%) → beauty (remainder).
  /// Rating is resolved from content unless the prefix already hard-codes one.
  String assembleFinalPrompt({
    required String sceneTags,
    String? commonPrefix,
    String? characterAppearance,
    String? personaAppearance,
    String? beautyBoost,
    int maxTokens = maxPromptTokens,
  }) {
    final beauty = beautyBoost == null
        ? defaultBeautyBoost
        : beautyBoost.trim();
    final prefix = (commonPrefix == null || commonPrefix.trim().isEmpty)
        ? defaultCommonPrefix
        : commonPrefix.trim();

    final ratingPlaceholder = prefix.contains('{rating}');
    final prefixForCost = prefix
        .replaceAll('{prompt}', ' ')
        .replaceAll('{rating}', 'rating:explicit');
    final prefixShellCost = estimateClipTokens(prefixForCost);
    final bodyBudget =
        (maxTokens - prefixShellCost).clamp(0, maxTokens).toInt();

    final sceneCap = (bodyBudget * 0.55).floor().clamp(0, 90);
    final appearanceCap = (bodyBudget * 0.4).floor().clamp(0, 50);

    final scene = fitTagsToBudget(
      _stripRatingTags(_splitTags(sceneTags)),
      sceneCap,
    );
    var used = _tokensForTags(scene);
    final taken = {for (final tag in scene) tag.toLowerCase()};

    final appearances = fitTagsToBudget(
      [
        ..._stripRatingTags(_splitTags(characterAppearance ?? '')),
        ..._stripRatingTags(_splitTags(personaAppearance ?? '')),
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

    final rating = NoobaiDanbooruPromptSkill.resolveRatingTag(
      [sceneTags, characterAppearance ?? '', personaAppearance ?? ''].join(', '),
    );

    if (body.isEmpty) {
      final emptyShell = prefix
          .replaceAll('{prompt}', '')
          .replaceAll('{rating}', rating);
      return fitTagsToBudget(_splitTags(emptyShell), maxTokens).join(', ');
    }

    var assembled = prefix.contains('{prompt}')
        ? prefix.replaceAll('{prompt}', body.join(', '))
        : '${_splitTags(prefix).join(', ')}, ${body.join(', ')}';

    if (ratingPlaceholder) {
      assembled = assembled.replaceAll('{rating}', rating);
    } else if (!_splitTags(assembled).any(
      (tag) => tag.toLowerCase().startsWith('rating:'),
    )) {
      assembled = '$assembled, $rating';
    }

    // Drop contradictory clothing-ish leftovers is left to the LLM; we only
    // ensure a single rating tag survives.
    return fitTagsToBudget(
      _dedupeRatingTags(_splitTags(assembled), preferred: rating),
      maxTokens,
    ).join(', ');
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

  List<String> _stripRatingTags(List<String> tags) {
    return tags
        .where((tag) => !tag.toLowerCase().startsWith('rating:'))
        .toList();
  }

  List<String> _dedupeRatingTags(
    List<String> tags, {
    required String preferred,
  }) {
    final out = <String>[];
    var sawRating = false;
    for (final tag in tags) {
      if (tag.toLowerCase().startsWith('rating:')) {
        if (sawRating) continue;
        out.add(preferred);
        sawRating = true;
      } else {
        out.add(tag);
      }
    }
    if (!sawRating) out.add(preferred);
    return out;
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
    // Soft-cap verbose model dumps before final assemble (SDXL budget).
    return fitTagsToBudget(_splitTags(text), 80).join(', ');
  }

  String _cleanScene(String sceneText) {
    var text = sceneText.trim();
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= _maxFallbackLength) return text;
    return text.substring(0, _maxFallbackLength).trim();
  }
}
