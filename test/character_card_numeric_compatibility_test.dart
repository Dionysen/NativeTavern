import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/domain/services/import_service.dart';

void main() {
  test('imports string-valued depth prompt fields from community cards',
      () async {
    final service = ImportService('/tmp/native_tavern_character_test');

    final character = await service.importFromJson(jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': 'String numeric card',
        'description': 'A card exported by a community tool',
        'extensions': {
          'depth_prompt': {
            'depth': '3',
            'prompt': 'Remember the scene',
            'role': 'system',
          },
          'talkativeness': '0.75',
        },
      },
    }));

    expect(character.depthPrompt?.depth, 3);
    expect(character.talkativeness, 0.75);
  });

  test('restores string-valued character book numbers and flags', () {
    final character = Character.fromJson({
      'id': 'legacy-card',
      'name': 'Legacy card',
      'characterBook': {
        'token_budget': '4096',
        'scan_depth': 'false',
        'recursive_scanning': '1',
        'entries': [
          {
            'id': '7',
            'insertion_order': '12',
            'priority': '25',
            'position': '1',
            'enabled': '0',
            'case_sensitive': 'true',
            'constant': '1',
            'selective': 'false',
          },
        ],
      },
      'extensions': {
        'depth_prompt': {'depth': '2', 'prompt': 'A note'},
        'talkativeness': '0.25',
      },
      'createdAt': '2026-08-29T00:00:00.000Z',
      'modifiedAt': '2026-08-29T00:00:00.000Z',
    });

    expect(character.depthPrompt?.depth, 2);
    expect(character.talkativeness, 0.25);
    final book = character.characterBook!;
    expect(book.tokenBudget, 4096);
    expect(book.scanDepth, 0);
    expect(book.recursiveScanning, isTrue);
    expect(book.entries.single.id, 7);
    expect(book.entries.single.insertionOrder, 12);
    expect(book.entries.single.priority, 25);
    expect(book.entries.single.position, 1);
    expect(book.entries.single.enabled, isFalse);
    expect(book.entries.single.caseSensitive, isTrue);
    expect(book.entries.single.constant, isTrue);
    expect(book.entries.single.selective, isFalse);
  });
}
