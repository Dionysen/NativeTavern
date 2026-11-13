import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/sprite.dart';
import 'package:native_tavern/domain/services/sprite_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpritePack', () {
    test('falls back to the default emotion, then any sprite', () {
      final happy = _sprite('happy');
      final pack = SpritePack(
        characterId: 'c1',
        defaultEmotion: 'happy',
        sprites: {'happy': happy},
      );

      expect(pack.getSprite('sad'), same(happy));
      expect(pack.hasSprites, isTrue);
      expect(pack.availableEmotions, ['happy']);
    });

    test('round-trips through json', () {
      final created = DateTime.utc(2026, 1, 2);
      final pack = SpritePack(
        characterId: 'c1',
        defaultEmotion: 'neutral',
        sprites: {
          'neutral': Sprite(
            id: 's1',
            characterId: 'c1',
            emotion: 'neutral',
            imagePath: '/tmp/neutral.png',
            createdAt: created,
          ),
        },
      );

      final restored = SpritePack.fromJson(pack.toJson());
      expect(restored.characterId, 'c1');
      expect(restored.defaultEmotion, 'neutral');
      expect(restored.sprites['neutral']!.imagePath, '/tmp/neutral.png');
      expect(restored.sprites['neutral']!.createdAt, created);
    });
  });

  group('SpriteService', () {
    late Directory tempDir;
    late SpriteService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('nt_sprites');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      service = SpriteService();
    });

    tearDown(() {
      service.clearCache();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('stores a sprite and resolves the emotion in a message action', () async {
      final source = File(p.join(tempDir.path, 'smile.png'))
        ..writeAsStringSync('png');
      await service.addSprite(
        characterId: 'hero',
        emotion: SpriteEmotion.happy.id,
        sourceImage: source,
      );

      final sprite = await service.getSpriteForMessage('hero', '*smiles*');
      expect(sprite, isNotNull);
      expect(sprite!.emotion, SpriteEmotion.happy.id);
      expect(File(sprite.imagePath).existsSync(), isTrue);
      expect(await service.hasSprites('hero'), isTrue);
      expect(await service.getAvailableEmotions('hero'), [SpriteEmotion.happy.id]);
    });

    test('imports images whose filenames match an emotion keyword', () async {
      final sourceDir = Directory(p.join(tempDir.path, 'incoming'))
        ..createSync();
      File(p.join(sourceDir.path, 'angry.png')).writeAsStringSync('a');
      File(p.join(sourceDir.path, 'notes.txt')).writeAsStringSync('skip');

      final imported =
          await service.importSpritesFromDirectory('hero', sourceDir);

      expect(imported, 1);
      final sprite =
          await service.getSpriteForEmotion('hero', SpriteEmotion.angry.id);
      expect(sprite, isNotNull);
      expect(await service.importSpritesFromDirectory(
        'hero',
        Directory(p.join(tempDir.path, 'missing')),
      ), 0);
    });

    test('removing a sprite deletes its file and leaves an empty pack', () async {
      final source = File(p.join(tempDir.path, 'yawn.png'))
        ..writeAsStringSync('png');
      final sprite = await service.addSprite(
        characterId: 'hero',
        emotion: SpriteEmotion.tired.id,
        sourceImage: source,
      );

      await service.removeSprite('hero', SpriteEmotion.tired.id);

      expect(File(sprite.imagePath).existsSync(), isFalse);
      expect(await service.hasSprites('hero'), isFalse);
    });

    test('a corrupt pack file loads as an empty pack', () async {
      final dir = await service.getSpritesDirectory('hero');
      File(p.join(dir.path, 'sprite_pack.json')).writeAsStringSync('{');

      final pack = await service.loadSpritePack('hero');
      expect(pack.hasSprites, isFalse);
      expect(pack.characterId, 'hero');
    });
  });
}

Sprite _sprite(String emotion) {
  return Sprite(
    id: emotion,
    characterId: 'c1',
    emotion: emotion,
    imagePath: '/$emotion.png',
    createdAt: DateTime.utc(2026),
  );
}
