import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/world_info.dart';

/// Parses SillyTavern (and NativeTavern) world info JSON into full
/// [WorldInfoEntry] objects, preserving behavioral fields: constant,
/// position, order, probability, timed effects, recursion flags, role, etc.
///
/// Pure functions - no I/O - so import fidelity is unit-testable.
class WorldInfoImport {
  /// Parse all entries from a world info book JSON.
  /// [worldInfoId] is stamped on every entry.
  static List<WorldInfoEntry> parseEntries(
    Map<String, dynamic> json,
    String worldInfoId, {
    String Function()? idGenerator,
  }) {
    final rawEntries = <Map<String, dynamic>>[];

    final entriesValue = json['entries'];
    if (entriesValue is Map) {
      // SillyTavern format: entries is {uid: entry}
      for (final value in entriesValue.values) {
        if (value is Map) {
          rawEntries.add(Map<String, dynamic>.from(value));
        }
      }
    } else if (entriesValue is List) {
      // NativeTavern/V2-card format: entries is a list
      for (final value in entriesValue) {
        if (value is Map) {
          rawEntries.add(Map<String, dynamic>.from(value));
        }
      }
    }

    var counter = 0;
    return rawEntries.map((raw) {
      counter++;
      final id = idGenerator?.call() ??
          '${DateTime.now().millisecondsSinceEpoch}_$counter';
      return parseEntry(raw, worldInfoId, id);
    }).toList();
  }

  /// Convert an embedded character_book into full [WorldInfoEntry]s.
  static List<WorldInfoEntry> parseCharacterBookEntries(
    CharacterBook book,
    String worldInfoId, {
    String Function()? idGenerator,
  }) {
    var counter = 0;
    return book.entries.map((entry) {
      counter++;
      final id = idGenerator?.call() ??
          '${DateTime.now().millisecondsSinceEpoch}_$counter';
      final raw = entry.raw.isNotEmpty ? entry.raw : entry.toJson();
      return parseEntry(raw, worldInfoId, id);
    }).toList();
  }

  /// Parse a single ST/NT entry into a full [WorldInfoEntry].
  ///
  /// Character-card `character_book` entries often stash behavioral fields
  /// under `extensions` (snake_case). Those are lifted when top-level is
  /// missing so embedded lorebooks match standalone WI import fidelity.
  static WorldInfoEntry parseEntry(
    Map<String, dynamic> data,
    String worldInfoId,
    String id,
  ) {
    final normalized = _normalizeEntry(data);
    final position = _parsePosition(normalized['position']);
    final probability = _intOf(normalized['probability']) ?? 100;
    final extensions = normalized['extensions'] is Map
        ? Map<String, dynamic>.from(normalized['extensions'] as Map)
        : <String, dynamic>{};

    return WorldInfoEntry(
      id: id,
      worldInfoId: worldInfoId,
      keys: _stringList(normalized['keys'] ?? normalized['key']),
      secondaryKeys: _stringList(
        normalized['secondaryKeys'] ??
            normalized['secondary_keys'] ??
            normalized['keysecondary'],
      ),
      content: normalized['content']?.toString() ?? '',
      comment: normalized['comment']?.toString() ??
          normalized['name']?.toString() ??
          '',
      enabled: !(_boolOf(normalized['disable']) ?? false) &&
          (_boolOf(normalized['enabled']) ?? true),
      constant: _boolOf(normalized['constant']) ?? false,
      selective: _boolOf(normalized['selective']) ?? false,
      insertionOrder: _intOf(
            normalized['insertionOrder'] ??
                normalized['insertion_order'] ??
                normalized['order'],
          ) ??
          100,
      caseSensitive: _boolOf(
            normalized['caseSensitive'] ?? normalized['case_sensitive'],
          ) ??
          false,
      matchWholeWords: _boolOf(
            normalized['matchWholeWords'] ?? normalized['match_whole_words'],
          ) ??
          false,
      useGroupScoring: _boolOf(
            normalized['useGroupScoring'] ?? normalized['use_group_scoring'],
          ) ??
          false,
      probability: probability,
      useProbability: _boolOf(
            normalized['useProbability'] ?? normalized['use_probability'],
          ) ??
          (probability < 100),
      position: position,
      depth: _intOf(normalized['depth']) ?? 4,
      group: (normalized['group']?.toString().isNotEmpty ?? false)
          ? normalized['group'].toString()
          : null,
      groupWeight: _intOf(
            normalized['groupWeight'] ?? normalized['group_weight'],
          ) ??
          100,
      groupOverride: _intOf(
            normalized['groupOverride'] ?? normalized['group_override'],
          ) ??
          (_boolOf(normalized['groupOverride'] ?? normalized['group_override']) ==
                  true
              ? 1
              : 0),
      preventRecursion: _boolOf(
            normalized['preventRecursion'] ?? normalized['prevent_recursion'],
          ) ??
          false,
      delayUntilRecursion: _boolOf(
            normalized['delayUntilRecursion'] ??
                normalized['delay_until_recursion'],
          ) ??
          false,
      excludeRecursion: _boolOf(
            normalized['excludeRecursion'] ?? normalized['exclude_recursion'],
          ) ??
          false,
      scanDepth: _intOf(
            normalized['scanDepth'] ?? normalized['scan_depth'],
          ) ??
          0,
      role: _parseRole(normalized['role']),
      timedEffects: WorldInfoTimedEffects(
        sticky: _intOf(normalized['sticky']) ?? 0,
        cooldown: _intOf(normalized['cooldown']) ?? 0,
        delay: _intOf(normalized['delay']) ?? 0,
      ),
      displayIndex: _intOf(
            normalized['displayIndex'] ?? normalized['display_index'],
          ) ??
          0,
      extensions: extensions,
    );
  }

  /// Merge advanced model fields into [extensions] so they survive DB storage
  /// that only persists a subset of columns + extensionsJson.
  static Map<String, dynamic> extensionsForPersistence(WorldInfoEntry entry) {
    final ext = Map<String, dynamic>.from(entry.extensions);
    ext['sticky'] = entry.timedEffects.sticky;
    ext['cooldown'] = entry.timedEffects.cooldown;
    ext['delay'] = entry.timedEffects.delay;
    ext['role'] = entry.role.index;
    ext['useProbability'] = entry.useProbability;
    ext['excludeRecursion'] = entry.excludeRecursion;
    ext['groupOverride'] = entry.groupOverride;
    ext['displayIndex'] = entry.displayIndex;
    return ext;
  }

  /// Restore advanced fields previously packed into [extensionsJson].
  static WorldInfoEntry withExtensionsRestored(
    WorldInfoEntry entry,
    Map<String, dynamic> extensions,
  ) {
    if (extensions.isEmpty) return entry.copyWith(extensions: extensions);
    return entry.copyWith(
      extensions: extensions,
      role: _parseRole(extensions['role']),
      timedEffects: WorldInfoTimedEffects(
        sticky: _intOf(extensions['sticky']) ?? entry.timedEffects.sticky,
        cooldown: _intOf(extensions['cooldown']) ?? entry.timedEffects.cooldown,
        delay: _intOf(extensions['delay']) ?? entry.timedEffects.delay,
      ),
      useProbability: _boolOf(
            extensions['useProbability'] ?? extensions['use_probability'],
          ) ??
          entry.useProbability,
      excludeRecursion: _boolOf(
            extensions['excludeRecursion'] ?? extensions['exclude_recursion'],
          ) ??
          entry.excludeRecursion,
      groupOverride: _intOf(
            extensions['groupOverride'] ?? extensions['group_override'],
          ) ??
          entry.groupOverride,
      displayIndex: _intOf(
            extensions['displayIndex'] ?? extensions['display_index'],
          ) ??
          entry.displayIndex,
    );
  }

  /// Lift character_book `extensions.*` behavioral fields to top-level when
  /// missing. Does not override an existing top-level value.
  static Map<String, dynamic> _normalizeEntry(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    final extRaw = data['extensions'];
    if (extRaw is! Map) return out;
    final ext = Map<String, dynamic>.from(extRaw);

    void lift(String topKey, List<String> extKeys) {
      if (_hasValue(out[topKey])) return;
      for (final key in extKeys) {
        if (_hasValue(ext[key])) {
          out[topKey] = ext[key];
          return;
        }
      }
    }

    lift('probability', ['probability']);
    lift('useProbability', ['useProbability', 'use_probability']);
    lift('depth', ['depth']);
    lift('sticky', ['sticky']);
    lift('cooldown', ['cooldown']);
    lift('delay', ['delay']);
    lift('preventRecursion', ['preventRecursion', 'prevent_recursion']);
    lift('delayUntilRecursion', [
      'delayUntilRecursion',
      'delay_until_recursion',
    ]);
    lift('excludeRecursion', ['excludeRecursion', 'exclude_recursion']);
    lift('role', ['role']);
    lift('scanDepth', ['scanDepth', 'scan_depth']);
    lift('matchWholeWords', ['matchWholeWords', 'match_whole_words']);
    lift('useGroupScoring', ['useGroupScoring', 'use_group_scoring']);
    lift('caseSensitive', ['caseSensitive', 'case_sensitive']);
    lift('group', ['group']);
    lift('groupWeight', ['groupWeight', 'group_weight']);
    lift('groupOverride', ['groupOverride', 'group_override']);
    lift('displayIndex', ['displayIndex', 'display_index']);
    lift('insertionOrder', ['insertion_order', 'order', 'insertionOrder']);
    // Only lift WI-style position when top-level is absent. Character cards
    // use top-level 0/1 (before/after char defs); don't let extensions win.
    lift('position', ['position']);

    out['extensions'] = ext;
    return out;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    return true;
  }

  static WorldInfoPosition _parsePosition(dynamic value) {
    final index = _intOf(value) ?? 0;
    if (index >= 0 && index < WorldInfoPosition.values.length) {
      return WorldInfoPosition.values[index];
    }
    return WorldInfoPosition.before;
  }

  static WorldInfoRole _parseRole(dynamic value) {
    final index = _intOf(value);
    if (index != null && index >= 0 && index < WorldInfoRole.values.length) {
      return WorldInfoRole.values[index];
    }
    return WorldInfoRole.system;
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static bool? _boolOf(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  static int? _intOf(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
