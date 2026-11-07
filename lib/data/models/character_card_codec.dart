import 'dart:convert';

import 'package:native_tavern/data/models/character.dart';

/// SillyTavern / chara_card_v3 import & export helpers.
///
/// Keeps unmapped `data` keys in [Character.cardExtras] so round-trips stay
/// format-compatible.
class CharacterCardCodec {
  CharacterCardCodec._();

  /// Keys mapped onto first-class [Character] fields (not stored in cardExtras).
  static const mappedDataKeys = <String>{
    'name',
    'description',
    'personality',
    'scenario',
    'first_mes',
    'alternate_greetings',
    'mes_example',
    'system_prompt',
    'post_history_instructions',
    'creator_notes',
    'tags',
    'creator',
    'character_version',
    'extensions',
    'character_book',
  };

  /// Internal storage key inside extensionsJson (stripped on card export).
  static const cardExtrasStorageKey = '__nt_card_extras';

  static Character parse(
    Map<String, dynamic> json, {
    required String Function() generateId,
  }) {
    String name = '';
    String description = '';
    String personality = '';
    String scenario = '';
    String firstMessage = '';
    List<String> alternateGreetings = [];
    String exampleMessages = '';
    String systemPrompt = '';
    String postHistoryInstructions = '';
    String creatorNotes = '';
    List<String> tags = [];
    String creator = '';
    String version = '';
    Map<String, dynamic> extensions = {};
    CharacterBook? characterBook;
    Map<String, dynamic> cardExtras = {};

    if (json.containsKey('spec') && json.containsKey('data')) {
      final data = Map<String, dynamic>.from(
        json['data'] as Map? ?? const {},
      );
      name = data['name']?.toString() ?? '';
      description = data['description']?.toString() ?? '';
      personality = data['personality']?.toString() ?? '';
      scenario = data['scenario']?.toString() ?? '';
      firstMessage = data['first_mes']?.toString() ?? '';
      alternateGreetings = _stringList(data['alternate_greetings']);
      exampleMessages = data['mes_example']?.toString() ?? '';
      systemPrompt = data['system_prompt']?.toString() ?? '';
      postHistoryInstructions =
          data['post_history_instructions']?.toString() ?? '';
      creatorNotes = data['creator_notes']?.toString() ?? '';
      tags = _stringList(data['tags']);
      creator = data['creator']?.toString() ?? '';
      version = data['character_version']?.toString() ?? '';
      extensions = _mapOf(data['extensions']);
      if (data['character_book'] is Map) {
        characterBook = CharacterBook.fromJson(
          Map<String, dynamic>.from(data['character_book'] as Map),
        );
      }
      cardExtras = _extrasFromData(data);
    } else if (json.containsKey('data')) {
      final data = Map<String, dynamic>.from(
        json['data'] as Map? ?? const {},
      );
      name = data['name']?.toString() ?? json['name']?.toString() ?? '';
      description = data['description']?.toString() ?? '';
      personality = data['personality']?.toString() ?? '';
      scenario = data['scenario']?.toString() ?? '';
      firstMessage = data['first_mes']?.toString() ?? '';
      alternateGreetings = _stringList(data['alternate_greetings']);
      exampleMessages = data['mes_example']?.toString() ?? '';
      systemPrompt = data['system_prompt']?.toString() ?? '';
      postHistoryInstructions =
          data['post_history_instructions']?.toString() ?? '';
      creatorNotes = data['creator_notes']?.toString() ?? '';
      tags = _stringList(data['tags']);
      creator = data['creator']?.toString() ?? '';
      version = data['character_version']?.toString() ?? '';
      extensions = _mapOf(data['extensions']);
      if (data['character_book'] is Map) {
        characterBook = CharacterBook.fromJson(
          Map<String, dynamic>.from(data['character_book'] as Map),
        );
      }
      cardExtras = _extrasFromData(data);
    } else {
      name = json['name']?.toString() ?? json['char_name']?.toString() ?? '';
      description = json['description']?.toString() ??
          json['char_persona']?.toString() ??
          '';
      personality = json['personality']?.toString() ?? '';
      scenario = json['scenario']?.toString() ??
          json['world_scenario']?.toString() ??
          '';
      firstMessage = json['first_mes']?.toString() ??
          json['char_greeting']?.toString() ??
          '';
      exampleMessages = json['mes_example']?.toString() ??
          json['example_dialogue']?.toString() ??
          '';
    }

    final depthPrompt = Character.depthPromptFromExtensions(extensions);
    final talkativeness = extensions.containsKey('talkativeness') ||
            !json.containsKey('talkativeness')
        ? Character.talkativenessFromExtensions(extensions)
        : Character.talkativenessFromExtensions(json);

    final now = DateTime.now();
    return Character(
      id: generateId(),
      name: name,
      description: description,
      personality: personality,
      scenario: scenario,
      firstMessage: firstMessage,
      alternateGreetings: alternateGreetings,
      exampleMessages: exampleMessages,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      creatorNotes: creatorNotes,
      tags: tags,
      creator: creator,
      version: version,
      extensions: extensions,
      characterBook: characterBook,
      cardExtras: cardExtras,
      depthPrompt: depthPrompt,
      talkativeness: talkativeness,
      createdAt: now,
      modifiedAt: now,
    );
  }

  /// V3 card JSON (`spec` + `data`) for PNG / CharX / file export.
  static Map<String, dynamic> toV3Json(Character character) {
    final data = <String, dynamic>{
      ...character.cardExtras,
      'name': character.name,
      'description': character.description,
      'personality': character.personality,
      'scenario': character.scenario,
      'first_mes': character.firstMessage,
      'alternate_greetings': character.alternateGreetings,
      'mes_example': character.exampleMessages,
      'system_prompt': character.systemPrompt,
      'post_history_instructions': character.postHistoryInstructions,
      'creator_notes': character.creatorNotes,
      'tags': character.tags,
      'creator': character.creator,
      'character_version': character.version,
      'extensions': character.extensionsForExport(),
    };

    if (character.characterBook != null) {
      data['character_book'] = character.characterBook!.toJson();
    }

    return {
      'spec': 'chara_card_v3',
      'spec_version': '3.0',
      'data': data,
    };
  }

  static String toV3JsonString(Character character) =>
      jsonEncode(toV3Json(character));

  /// Merge cardExtras into extensions map for DB storage; strip on read.
  static Map<String, dynamic> extensionsForStorage(Character character) {
    final stored = character.extensionsForExport();
    if (character.cardExtras.isNotEmpty) {
      stored[cardExtrasStorageKey] =
          Map<String, dynamic>.from(character.cardExtras);
    }
    return stored;
  }

  static (Map<String, dynamic> extensions, Map<String, dynamic> cardExtras)
      splitStoredExtensions(Map<String, dynamic> raw) {
    final extensions = Map<String, dynamic>.from(raw);
    final extrasRaw = extensions.remove(cardExtrasStorageKey);
    final cardExtras = extrasRaw is Map
        ? Map<String, dynamic>.from(extrasRaw)
        : <String, dynamic>{};
    return (extensions, cardExtras);
  }

  static Map<String, dynamic> _extrasFromData(Map<String, dynamic> data) {
    final extras = <String, dynamic>{};
    for (final entry in data.entries) {
      if (!mappedDataKeys.contains(entry.key)) {
        extras[entry.key] = entry.value;
      }
    }
    return extras;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}
