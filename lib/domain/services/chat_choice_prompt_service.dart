import 'dart:convert';

import 'package:native_tavern/data/models/chat_choice_config.dart';

/// Builds the system instruction and parses model output for reply choices.
abstract final class ChatChoicePromptService {
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
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return const [];
    try {
      final decoded =
          (const JsonDecoder()).convert(text.substring(start, end + 1));
      if (decoded is! Map) return const [];
      final choices = decoded['choices'];
      if (choices is! List) return const [];
      return choices.whereType<String>().toList(growable: false);
    } catch (_) {
      return const [];
    }
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
