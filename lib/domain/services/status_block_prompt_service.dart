import 'dart:convert';

import 'package:native_tavern/data/models/status_block_config.dart';

class StatusBlockValidationResult {
  final StatusBlockSnapshot? snapshot;
  final bool isComplete;
  final String? validationError;

  const StatusBlockValidationResult({
    required this.snapshot,
    required this.isComplete,
    this.validationError,
  });
}

/// Builds the system instruction and parses model output for status blocks.
abstract final class StatusBlockPromptService {
  static const int maxFormatRetries = 2;

  static String buildSystemPrompt({
    required StatusBlockConfig config,
    required List<String> characterNames,
    StatusBlockSnapshot? previous,
  }) {
    final fields = config.normalizedFields()
        .where((f) => f.id != 'name')
        .toList(growable: false);
    final fieldLines = StringBuffer();
    for (final field in fields) {
      fieldLines.writeln('- ${field.label}');
    }
    final characterLines = StringBuffer();
    for (final name in characterNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      characterLines.writeln('- $trimmed');
    }

    var template = config.promptTemplate.trim();
    if (template.isEmpty) {
      template = StatusBlockConfig.defaultPromptTemplate;
    }

    return template
        .replaceAll('{{field_lines}}', fieldLines.toString().trim())
        .replaceAll('{{character_lines}}', characterLines.toString().trim())
        .replaceAll(
          '{{previous_status}}',
          previous == null || previous.isEmpty
              ? '(none)'
              : previous.toCompactText(),
        );
  }

  static StatusBlockValidationResult parseAndValidate(
    String raw,
    StatusBlockConfig config, {
    required List<String> expectedNames,
  }) {
    final snapshot = parseSnapshot(raw, config);
    if (snapshot == null || snapshot.characters.isEmpty) {
      return const StatusBlockValidationResult(
        snapshot: null,
        isComplete: false,
        validationError:
            'Expected JSON {"characters":[{"name":"...","fields":{...}}]}.',
      );
    }

    final expected = expectedNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    if (expected.isNotEmpty) {
      final got = snapshot.characters
          .map((c) => c.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet();
      if (got.isEmpty) {
        return StatusBlockValidationResult(
          snapshot: snapshot,
          isComplete: false,
          validationError: 'Missing character names in status JSON.',
        );
      }
    }

    return StatusBlockValidationResult(
      snapshot: snapshot,
      isComplete: true,
    );
  }

  static String buildFormatRepairPrompt({
    required StatusBlockConfig config,
    required String validationError,
  }) {
    final fieldLabels = config
        .normalizedFields()
        .where((f) => f.id != 'name')
        .map((f) => f.label)
        .join(', ');
    return '''Your previous reply did not match the required format.
$validationError

Regenerate now. Return ONLY valid JSON:
{"characters":[{"name":"Display Name","fields":{"$fieldLabels":"..."}}]}
Use the exact field labels configured. Do not wrap in markdown.''';
  }

  static StatusBlockSnapshot? parseSnapshot(
    String raw,
    StatusBlockConfig config,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final decoded = _decodeJsonCandidate(trimmed);
    if (decoded is! Map) return null;

    final map = Map<String, dynamic>.from(decoded);
    final snapshot = StatusBlockSnapshot.fromJson({
      ...map,
      'source': 'builtin',
    });
    if (snapshot.characters.isEmpty) return null;

    final normalized = snapshot.characters.map((character) {
      final fields = <String, String>{};
      for (final entry in character.fields.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        fields[entry.key] = value;
      }
      return StatusCharacterSnapshot(
        name: character.name.trim(),
        fields: fields,
      );
    }).where((c) => c.name.isNotEmpty).toList(growable: false);

    if (normalized.isEmpty) return null;
    return StatusBlockSnapshot(
      source: 'builtin',
      characters: normalized,
    );
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
    for (final candidate in candidates) {
      try {
        return jsonDecode(candidate);
      } catch (_) {}
    }
    return null;
  }
}
