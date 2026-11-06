import 'dart:convert';

import 'package:native_tavern/data/models/chat_choice_config.dart';

/// Outcome of parsing and validating model output for reply choices.
class ChatChoiceParseResult {
  final List<String> choices;
  final bool isComplete;
  final String? validationError;

  const ChatChoiceParseResult({
    required this.choices,
    required this.isComplete,
    this.validationError,
  });
}

/// Builds the system instruction and parses model output for reply choices.
abstract final class ChatChoicePromptService {
  /// Extra LLM calls after the first when format validation fails.
  static const int maxFormatRetries = 2;

  static String buildSystemPrompt(ChatChoiceConfig config) {
    final count = config.choiceCount.clamp(
      ChatChoiceConfig.minChoiceCount,
      ChatChoiceConfig.maxChoiceCount,
    );
    final maxChars = config.maxCharsPerChoice.clamp(8, 500);
    final slots = config.normalizedSlots();
    final optionLines = StringBuffer();
    for (var i = 0; i < slots.length; i++) {
      final tendency = slots[i].tendency.trim();
      final guidance = tendency.isEmpty
          ? 'Any appropriate direction for this scene.'
          : tendency;
      optionLines.writeln('Option ${i + 1}: $guidance');
    }

    var template = config.promptTemplate.trim();
    if (template.isEmpty) {
      template = ChatChoiceConfig.defaultPromptTemplate;
    }

    var result = template
        .replaceAll('{{count}}', '$count')
        .replaceAll('{{max_chars}}', '$maxChars')
        .replaceAll('{{option_lines}}', optionLines.toString().trim());

    for (var i = 0; i < slots.length; i++) {
      final tendency = slots[i].tendency.trim();
      result = result.replaceAll(
        '{{tendency_${i + 1}}}',
        tendency.isEmpty ? 'any appropriate direction' : tendency,
      );
    }
    return result;
  }

  /// Parses raw model text and checks whether it meets the configured format.
  static ChatChoiceParseResult parseAndValidate(
    String raw,
    ChatChoiceConfig config,
  ) {
    final expected = config.choiceCount.clamp(
      ChatChoiceConfig.minChoiceCount,
      ChatChoiceConfig.maxChoiceCount,
    );
    final choices = parseChoices(raw, config);
    if (choices.length < expected) {
      return ChatChoiceParseResult(
        choices: choices,
        isComplete: false,
        validationError:
            'Expected exactly $expected distinct choices in JSON '
            '{"choices":["..."]}, but got ${choices.length}.',
      );
    }
    return ChatChoiceParseResult(
      choices: choices,
      isComplete: true,
    );
  }

  /// Feedback appended on retry so the model can correct its previous output.
  static String buildFormatRepairPrompt({
    required ChatChoiceConfig config,
    required String validationError,
  }) {
    final count = config.choiceCount.clamp(
      ChatChoiceConfig.minChoiceCount,
      ChatChoiceConfig.maxChoiceCount,
    );
    final maxChars = config.maxCharsPerChoice.clamp(8, 500);
    return '''Your previous reply did not match the required format.
$validationError

Regenerate now. Return ONLY valid JSON with exactly $count non-empty strings:
{"choices":["option1","option2"]}
Each option must be at most $maxChars characters.
Do not wrap in markdown. Do not add numbering, commentary, or prose outside the JSON object.''';
  }

  static List<String> parseChoices(
    String raw,
    ChatChoiceConfig config,
  ) {
    final count = config.choiceCount.clamp(
      ChatChoiceConfig.minChoiceCount,
      ChatChoiceConfig.maxChoiceCount,
    );
    final maxChars = config.maxCharsPerChoice.clamp(8, 500);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    List<String> candidates = _parseJsonChoices(trimmed);
    candidates = candidates.isEmpty ? _parseLineChoices(trimmed) : candidates;

    return candidates
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .map((c) => _truncateChars(c, maxChars))
        .take(count)
        .toList(growable: false);
  }

  static List<String> _parseJsonChoices(String text) {
    final decoded = _decodeJsonCandidate(text);
    if (decoded == null) return const [];

    if (decoded is List) {
      return _stringifyChoiceList(decoded);
    }
    if (decoded is Map) {
      final choices = decoded['choices'];
      if (choices is List) {
        return _stringifyChoiceList(choices);
      }
    }
    return const [];
  }

  static Object? _decodeJsonCandidate(String text) {
    final candidates = <String>[text];
    final fenceMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenceMatch != null) {
      candidates.insert(0, fenceMatch.group(1)!.trim());
    }

    final objectStart = text.indexOf('{');
    final objectEnd = text.lastIndexOf('}');
    if (objectStart >= 0 && objectEnd > objectStart) {
      candidates.add(text.substring(objectStart, objectEnd + 1));
    }

    final arrayStart = text.indexOf('[');
    final arrayEnd = text.lastIndexOf(']');
    if (arrayStart >= 0 && arrayEnd > arrayStart) {
      candidates.add(text.substring(arrayStart, arrayEnd + 1));
    }

    for (final candidate in candidates) {
      try {
        return (const JsonDecoder()).convert(candidate);
      } catch (_) {
        // Try next candidate.
      }
    }
    return null;
  }

  static List<String> _stringifyChoiceList(List<dynamic> choices) {
    return choices
        .map((item) {
          if (item is String) return item;
          if (item == null) return '';
          return item.toString();
        })
        .toList(growable: false);
  }

  static List<String> _parseLineChoices(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    for (final line in lines) {
      final cleaned = line
          .replaceFirst(RegExp(r'^\s*\d+[\).\:-]\s*'), '')
          .replaceFirst(RegExp(r'^\s*[-*]\s*'), '')
          .trim();
      if (cleaned.isNotEmpty) {
        result.add(cleaned);
      }
    }
    return result;
  }

  static String _truncateChars(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    if (maxChars <= 1) return text.substring(0, maxChars);
    return text.substring(0, maxChars - 1).trimRight() + '…';
  }
}
