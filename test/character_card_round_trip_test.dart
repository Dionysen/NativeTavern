import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/core/utils/png_text_chunks.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/character_card_codec.dart';
import 'package:native_tavern/domain/services/import_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String path;
  _FakePathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  late Directory tempDir;
  late ImportService service;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('nt_card_round_trip_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    service = ImportService(p.join(tempDir.path, 'NativeTavern'));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Map<String, dynamic> sampleV3() => {
        'spec': 'chara_card_v3',
        'spec_version': '3.0',
        'data': {
          'name': 'RoundTrip Hero',
          'description': 'A traveler',
          'personality': 'calm',
          'scenario': 'a quiet tavern',
          'first_mes': 'Hello there.',
          'alternate_greetings': ['Hi!', 'Hey.'],
          'mes_example': '{{user}}: hi\n{{char}}: hello',
          'system_prompt': 'Stay in character',
          'post_history_instructions': 'Be brief',
          'creator_notes': 'test card',
          'tags': ['test', 'roundtrip'],
          'creator': 'NativeTavern',
          'character_version': '1.2.3',
          'group_only_greetings': ['party hello'],
          'nickname': 'Hero',
          'extensions': {
            'talkativeness': 0.4,
            'depth_prompt': {
              'depth': 3,
              'prompt': 'Remember the inn',
              'role': 'system',
            },
            'world': 'demo-world',
          },
          'character_book': {
            'name': 'Hero book',
            'description': 'lore',
            'scan_depth': 42,
            'token_budget': 1024,
            'recursive_scanning': true,
            'extensions': {'custom_book': true},
            'entries': [
              {
                'id': 1,
                'keys': ['sword'],
                'secondary_keys': ['blade'],
                'content': 'A legendary blade.',
                'comment': 'weapon',
                'enabled': true,
                'insertion_order': 10,
                'case_sensitive': false,
                'name': 'Sword',
                'priority': 10,
                'constant': false,
                'selective': true,
                'position': 0,
                'extensions': {'probability': 80},
              },
            ],
          },
        },
      };

  test('JSON import/export preserves mapped fields, extras, and book scan_depth',
      () async {
    final imported = await service.importFromJson(jsonEncode(sampleV3()));
    expect(imported.name, 'RoundTrip Hero');
    expect(imported.cardExtras['group_only_greetings'], ['party hello']);
    expect(imported.cardExtras['nickname'], 'Hero');
    expect(imported.characterBook?.scanDepth, 42);
    expect(imported.depthPrompt?.prompt, 'Remember the inn');
    expect(imported.talkativeness, 0.4);
    expect(imported.extensions['world'], 'demo-world');

    final exported = jsonDecode(service.exportToJson(imported))
        as Map<String, dynamic>;
    expect(exported['spec'], 'chara_card_v3');
    final data = exported['data'] as Map<String, dynamic>;
    expect(data['name'], 'RoundTrip Hero');
    expect(data['group_only_greetings'], ['party hello']);
    expect(data['nickname'], 'Hero');
    expect(data['character_book']['scan_depth'], 42);
    expect(data['extensions']['world'], 'demo-world');
    expect(data['extensions']['talkativeness'], 0.4);
    expect(
      (data['character_book']['entries'] as List).single['extensions']
          ['probability'],
      80,
    );

    final reimported = await service.importFromJson(jsonEncode(exported));
    expect(reimported.name, imported.name);
    expect(reimported.description, imported.description);
    expect(reimported.cardExtras['nickname'], 'Hero');
    expect(reimported.characterBook?.scanDepth, 42);
    expect(reimported.talkativeness, 0.4);
  });

  test('PNG export embeds ccv3 and chara and round-trips', () async {
    final imported = await service.importFromJson(jsonEncode(sampleV3()));
    final pngBytes = await service.exportToPng(imported, null);

    expect(extractPngTextChunk(pngBytes, 'ccv3'), isNotNull);
    expect(extractPngTextChunk(pngBytes, 'chara'), isNotNull);

    final fromPng = await service.importFromPngBytes(pngBytes);
    expect(fromPng.name, 'RoundTrip Hero');
    expect(fromPng.cardExtras['group_only_greetings'], ['party hello']);
    expect(fromPng.characterBook?.scanDepth, 42);
  });

  test('PNG re-export does not duplicate chara/ccv3 chunks', () async {
    final imported = await service.importFromJson(jsonEncode(sampleV3()));
    final once = await service.exportToPng(imported, null);
    final again = await service.exportToPng(
      imported,
      once,
    );

    var charaCount = 0;
    var ccv3Count = 0;
    var offset = 8;
    while (offset + 12 <= again.length) {
      final length = (again[offset] << 24) |
          (again[offset + 1] << 16) |
          (again[offset + 2] << 8) |
          again[offset + 3];
      final type =
          String.fromCharCodes(again.sublist(offset + 4, offset + 8));
      if (type == 'tEXt') {
        final data = again.sublist(offset + 8, offset + 8 + length);
        final sep = data.indexOf(0);
        if (sep > 0) {
          final keyword = latin1.decode(data.sublist(0, sep));
          if (keyword == 'chara') charaCount++;
          if (keyword == 'ccv3') ccv3Count++;
        }
      }
      if (type == 'IEND') break;
      offset += 12 + length;
    }

    expect(charaCount, 1);
    expect(ccv3Count, 1);
  });

  test('CharX export round-trips card.json fields', () async {
    final imported = await service.importFromJson(jsonEncode(sampleV3()));
    final archiveBytes = await service.exportToCharX(imported, null);
    final path = p.join(tempDir.path, 'hero.charx');
    await File(path).writeAsBytes(archiveBytes);

    final fromCharx = await service.importFromCharX(path);
    expect(fromCharx.name, 'RoundTrip Hero');
    expect(fromCharx.cardExtras['nickname'], 'Hero');
    expect(fromCharx.characterBook?.scanDepth, 42);
  });

  test('codec keeps legacy bool scan_depth convertible', () {
    final book = CharacterBook.fromJson({
      'scan_depth': false,
      'entries': [],
    });
    expect(book.scanDepth, 0);

    final on = CharacterBook.fromJson({
      'scan_depth': true,
      'entries': [],
    });
    expect(on.scanDepth, isNull);

    final exported = CharacterCardCodec.toV3Json(
      Character(
        id: '1',
        name: 'x',
        characterBook: CharacterBook(scanDepth: 7),
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(exported['data']['character_book']['scan_depth'], 7);
  });
}
