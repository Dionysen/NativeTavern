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
    required String userName,
    required List<String> sceneCharacterHints,
    StatusBlockSnapshot? previous,
  }) {
    final fields = config.normalizedFields()
        .where((f) => f.id != 'name')
        .toList(growable: false);
    final fieldLines = StringBuffer();
    for (final field in fields) {
      fieldLines.writeln('- ${field.label}');
    }

    final resolvedUser =
        userName.trim().isEmpty ? 'User' : userName.trim();
    final characterLines = StringBuffer()
      ..writeln(
        '- User persona — "name" must be exactly "$resolvedUser"',
      );
    if (sceneCharacterHints.isEmpty) {
      characterLines.writeln(
        '- Main NPC(s) currently in the scene — use the name they have '
        'in the story/dialogue, never the character-card file title',
      );
    } else {
      for (final hint in sceneCharacterHints) {
        final trimmed = hint.trim();
        if (trimmed.isEmpty) continue;
        characterLines.writeln(
          '- Also cover this person if they are in the scene: "$trimmed" '
          '(use their in-story name if the narrative calls them something else)',
        );
      }
    }

    var template = config.promptTemplate.trim();
    if (template.isEmpty) {
      template = StatusBlockConfig.defaultPromptTemplate;
    }

    return template
        .replaceAll('{{field_lines}}', fieldLines.toString().trim())
        .replaceAll('{{character_lines}}', characterLines.toString().trim())
        .replaceAll('{{user_name}}', resolvedUser)
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
    String userName = '',
  }) {
    final snapshot = parseSnapshot(raw, config, userName: userName);
    if (snapshot == null || snapshot.characters.isEmpty) {
      return const StatusBlockValidationResult(
        snapshot: null,
        isComplete: false,
        validationError:
            'Expected JSON {"characters":[{"name":"...","fields":{...}}]}.',
      );
    }

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
    StatusBlockConfig config, {
    String userName = '',
  }) {
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

    final resolvedUser = userName.trim();
    final normalized = snapshot.characters.map((character) {
      final fields = <String, String>{};
      for (final entry in character.fields.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        fields[entry.key] = value;
      }
      var name = character.name.trim();
      if (resolvedUser.isNotEmpty &&
          (name.isEmpty ||
              name == 'User' ||
              name == '{{user}}' ||
              name == '👤 User' ||
              name == '👤 {{user}}')) {
        name = resolvedUser;
      } else if (resolvedUser.isNotEmpty) {
        name = name
            .replaceAll('{{user}}', resolvedUser)
            .replaceAll('{{persona}}', resolvedUser);
      }
      return StatusCharacterSnapshot(
        name: name,
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
