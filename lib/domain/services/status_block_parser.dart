import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/status_block_config.dart';

/// Result of stripping embedded status markup from message content.
class StatusBlockParseResult {
  final String contentWithoutStatus;
  final StatusBlockSnapshot? snapshot;

  const StatusBlockParseResult({
    required this.contentWithoutStatus,
    this.snapshot,
  });
}

/// Parses card-authored `<Status_block>` / status YAML out of chat HTML.
abstract final class StatusBlockParser {
  static final RegExp _statusBlockTag = RegExp(
    r'<Status_block\b[^>]*>([\s\S]*?)</Status_block>',
    caseSensitive: false,
  );
  static final RegExp _detailsWithStatus = RegExp(
    r'<details\b[^>]*>[\s\S]*?</details>',
    caseSensitive: false,
  );
  static final RegExp _cardStatusHint = RegExp(
    r'<Status_block\b|状态栏\s*:',
    caseSensitive: false,
  );

  /// True when character card text already ships a status bar.
  static bool characterHasStatusBlock(Character character) {
    final samples = <String>[
      character.firstMessage,
      character.postHistoryInstructions,
      ...character.alternateGreetings,
    ];
    for (final sample in samples) {
      if (_cardStatusHint.hasMatch(sample)) return true;
    }
    return false;
  }

  /// Removes status markup from [content] and builds a structured snapshot.
  static StatusBlockParseResult parse(String content) {
    if (content.isEmpty) {
      return StatusBlockParseResult(contentWithoutStatus: content);
    }

    final characters = <StatusCharacterSnapshot>[];
    var remaining = content;

    // Prefer extracting whole <details> that contain a Status_block so the
    // "click to expand" chrome from the card does not leak as raw HTML.
    remaining = remaining.replaceAllMapped(_detailsWithStatus, (match) {
      final block = match.group(0)!;
      if (!_statusBlockTag.hasMatch(block) &&
          !RegExp(r'状态栏\s*:', caseSensitive: false).hasMatch(block)) {
        return block;
      }
      final inner = _statusBlockTag.firstMatch(block)?.group(1) ?? block;
      characters.addAll(_parseStatusBody(inner));
      return '';
    });

    remaining = remaining.replaceAllMapped(_statusBlockTag, (match) {
      characters.addAll(_parseStatusBody(match.group(1) ?? ''));
      return '';
    });

    remaining = remaining
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (characters.isEmpty) {
      return StatusBlockParseResult(contentWithoutStatus: content);
    }

    return StatusBlockParseResult(
      contentWithoutStatus: remaining,
      snapshot: StatusBlockSnapshot(
        source: 'parsed',
        characters: characters,
      ),
    );
  }

  static List<StatusCharacterSnapshot> _parseStatusBody(String raw) {
    final text = raw
        .replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    if (text.isEmpty) return const [];

    // Split on top-level "- 用户:" entries when present.
    final userChunks = RegExp(
      r'(?:^|\n)\s*-\s*用户\s*:',
      multiLine: true,
    ).allMatches(text).toList();

    if (userChunks.length >= 2) {
      final characters = <StatusCharacterSnapshot>[];
      for (var i = 0; i < userChunks.length; i++) {
        final start = userChunks[i].end;
        final end =
            i + 1 < userChunks.length ? userChunks[i + 1].start : text.length;
        final chunk = text.substring(start, end).trim();
        final parsed = _parseCharacterChunk(chunk);
        if (parsed != null) characters.add(parsed);
      }
      if (characters.isNotEmpty) return characters;
    }

    // Fallback: single character / flat field map.
    final single = _parseCharacterChunk(text);
    return single == null ? const [] : [single];
  }

  static StatusCharacterSnapshot? _parseCharacterChunk(String chunk) {
    final fields = <String, String>{};
    String name = '';

    // Match `名字: "..."`, `穿搭: "..."`, or unquoted `行动: ...`
    final fieldPattern = RegExp(
      r'(?:^|\n)\s*(?:-\s*)?([^\n:：]{1,40})\s*[:：]\s*(?:"([^"]*)"|([^\n]+))',
      multiLine: true,
    );
    for (final match in fieldPattern.allMatches(chunk)) {
      final label = (match.group(1) ?? '').trim();
      final value = ((match.group(2) ?? match.group(3) ?? '')).trim();
      if (label.isEmpty || value.isEmpty) continue;
      if (label == '名字' || label.toLowerCase() == 'name') {
        name = value;
        continue;
      }
      // Skip structural keys that are not character fields.
      if (label == '用户列表' ||
          label == '行动选项' ||
          label == '状态栏' ||
          label == '日期和时间' ||
          label == '地点' ||
          label == '选项') {
        continue;
      }
      fields[label] = value;
    }

    if (name.isEmpty && fields.isEmpty) return null;
    if (name.isEmpty) {
      name = fields.remove('角色') ?? fields.remove('character') ?? '';
    }
    if (name.isEmpty && fields.isEmpty) return null;
    return StatusCharacterSnapshot(name: name, fields: fields);
  }
}
