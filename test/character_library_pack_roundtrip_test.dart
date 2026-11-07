import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/models/character.dart' as models;
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/domain/services/character_library_pack_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

/// Minimal valid 1x1 PNG.
final Uint8List _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dataPath;
  late AppDatabase database;
  late CharacterFolderRepository folders;
  late CharacterRepository characters;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nt_pack_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    dataPath = p.join(tempDir.path, 'NativeTavern');
    await Directory(p.join(dataPath, 'avatars')).create(recursive: true);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    folders = CharacterFolderRepository(database);
    characters = CharacterRepository(database, dataPath);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('export then import restores ids, folders, and avatars', () async {
    final parent = await folders.createFolder('Fantasy');
    final child = await folders.createFolder('Elves', parentId: parent.id);

    final avatarA = File(p.join(dataPath, 'avatars', 'char-a.png'));
    final avatarB = File(p.join(dataPath, 'avatars', 'char-b.png'));
    await avatarA.writeAsBytes(_tinyPng);
    await avatarB.writeAsBytes(_tinyPng);

    final scout = await characters.createCharacter(
      models.Character(
        id: 'char-a',
        name: 'Elf Scout',
        description: 'A scout',
        assets: models.CharacterAssets(avatarPath: 'avatars/char-a.png'),
        createdAt: DateTime.utc(2024, 1, 1),
        modifiedAt: DateTime.utc(2024, 1, 1),
      ),
    );
    final mage = await characters.createCharacter(
      models.Character(
        id: 'char-b',
        name: 'Elf Mage',
        description: 'A mage',
        assets: models.CharacterAssets(avatarPath: 'avatars/char-b.png'),
        createdAt: DateTime.utc(2024, 1, 2),
        modifiedAt: DateTime.utc(2024, 1, 2),
      ),
    );
    await folders.moveCharactersToFolder([scout.id], folderId: child.id);
    await folders.moveCharactersToFolder([mage.id], folderId: parent.id);

    final packPath = p.join(tempDir.path, 'library.ntchars');
    final pack = CharacterLibraryPackService(
      characterRepository: characters,
      folderRepository: folders,
      dataPath: dataPath,
    );
    final exportResult = await pack.exportToFile(packPath);
    expect(exportResult.characterCount, 2);
    expect(exportResult.folderCount, 2);
    expect(exportResult.avatarCount, 2);
    expect(File(packPath).existsSync(), isTrue);

    await database.close();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    folders = CharacterFolderRepository(database);
    characters = CharacterRepository(database, dataPath);
    // Simulate fresh install: remove avatars then reimport from pack.
    await Directory(p.join(dataPath, 'avatars')).delete(recursive: true);
    await Directory(p.join(dataPath, 'avatars')).create(recursive: true);

    final importPack = CharacterLibraryPackService(
      characterRepository: characters,
      folderRepository: folders,
      dataPath: dataPath,
    );
    final importResult = await importPack.importFromFile(packPath);
    expect(importResult.errors, isEmpty, reason: importResult.errors.join('\n'));
    expect(importResult.created, 2);
    expect(importResult.updated, 0);
    expect(importResult.folderCount, 2);

    final all = await characters.getAllCharacters();
    expect(all.map((c) => c.id).toSet(), {'char-a', 'char-b'});
    expect(await folders.folderIdForCharacter('char-a'), child.id);
    expect(await folders.folderIdForCharacter('char-b'), parent.id);
    expect(File(p.join(dataPath, 'avatars', 'char-a.png')).existsSync(), isTrue);
    expect(File(p.join(dataPath, 'avatars', 'char-b.png')).existsSync(), isTrue);

    final rootFolders = await folders.listFolders();
    expect(rootFolders.single.id, parent.id);
    expect(rootFolders.single.name, 'Fantasy');
  });

  test('import overwrites matching character ids', () async {
    final avatar = File(p.join(dataPath, 'avatars', 'same.png'));
    await avatar.writeAsBytes(_tinyPng);

    await characters.createCharacter(
      models.Character(
        id: 'same-id',
        name: 'Old Name',
        description: 'old',
        assets: models.CharacterAssets(avatarPath: 'avatars/same.png'),
        createdAt: DateTime.utc(2024, 1, 1),
        modifiedAt: DateTime.utc(2024, 1, 1),
      ),
    );

    final packPath = p.join(tempDir.path, 'overwrite.ntchars');
    final pack = CharacterLibraryPackService(
      characterRepository: characters,
      folderRepository: folders,
      dataPath: dataPath,
    );
    await pack.exportToFile(packPath);

    // Change local copy then re-import the pack snapshot.
    await characters.updateCharacter(
      models.Character(
        id: 'same-id',
        name: 'Local Edit',
        description: 'changed locally',
        assets: models.CharacterAssets(avatarPath: 'avatars/same.png'),
        createdAt: DateTime.utc(2024, 1, 1),
        modifiedAt: DateTime.now(),
      ),
    );

    final importResult = await pack.importFromFile(packPath);
    expect(importResult.created, 0);
    expect(importResult.updated, 1);
    expect(importResult.failed, 0);

    final restored = await characters.getCharacter('same-id');
    expect(restored, isNotNull);
    expect(restored!.id, 'same-id');
    expect(restored.name, 'Old Name');
    expect(restored.description, 'old');
  });
}
