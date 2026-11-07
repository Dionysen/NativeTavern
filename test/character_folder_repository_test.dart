import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';

void main() {
  late AppDatabase database;
  late CharacterFolderRepository folders;

  Future<void> insertCharacter(String id, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.customStatement(
      'INSERT INTO characters (id, name, created_at, modified_at) '
      'VALUES (?, ?, ?, ?)',
      [id, name, now, now],
    );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    folders = CharacterFolderRepository(database);
    await insertCharacter('char-a', 'A');
    await insertCharacter('char-b', 'B');
  });

  tearDown(() async {
    await database.close();
  });

  test('creates folder, moves characters, and dissolves', () async {
    final folder = await folders.createFolder('Favorites');
    expect(folder.name, 'Favorites');
    expect(folder.parentId, isNull);

    await folders.moveCharactersToFolder(['char-a'], folderId: folder.id);
    expect(await folders.folderIdForCharacter('char-a'), folder.id);
    expect(await folders.folderIdForCharacter('char-b'), isNull);

    final listed = await folders.listFolders();
    expect(listed.single.characterCount, 1);
    expect(listed.single.previewCharacters.single.id, 'char-a');

    await folders.dissolveFolder(folder.id);
    expect(await folders.listFolders(), isEmpty);
    expect(await folders.folderIdForCharacter('char-a'), isNull);
  });

  test('move to root clears membership', () async {
    final folder = await folders.createFolder('Temp');
    await folders.moveCharactersToFolder(['char-a', 'char-b'], folderId: folder.id);
    await folders.moveCharactersToFolder(['char-a'], folderId: null);

    expect(await folders.folderIdForCharacter('char-a'), isNull);
    expect(await folders.folderIdForCharacter('char-b'), folder.id);
    final updated = await folders.getFolder(folder.id);
    expect(updated?.characterCount, 1);
  });

  test('ensureFolderPath creates nested folders idempotently', () async {
    final leafId = await folders.ensureFolderPath(['Fantasy', 'Elves']);
    expect(leafId, isNotNull);

    final rootFolders = await folders.listFolders();
    expect(rootFolders.single.name, 'Fantasy');

    final childFolders =
        await folders.listFolders(parentId: rootFolders.single.id);
    expect(childFolders.single.name, 'Elves');
    expect(childFolders.single.id, leafId);

    final again = await folders.ensureFolderPath(['Fantasy', 'Elves']);
    expect(again, leafId);
    expect(await folders.listAllFolders(), hasLength(2));

    expect(
      await folders.pathSegmentsForFolder(leafId!),
      ['Fantasy', 'Elves'],
    );
    expect(await folders.relativePathForFolder(leafId), 'Fantasy/Elves');
  });

  test('dissolve reparents child folders and keeps characters', () async {
    final parent = await folders.createFolder('Parent');
    final child = await folders.createFolder('Child', parentId: parent.id);
    await folders.moveCharactersToFolder(['char-a'], folderId: parent.id);

    await folders.dissolveFolder(parent.id);

    final remaining = await folders.listFolders();
    expect(remaining.single.id, child.id);
    expect(remaining.single.parentId, isNull);
    expect(await folders.folderIdForCharacter('char-a'), isNull);
  });

  test('deleteFolderTree removes subtree and returns character ids', () async {
    final parent = await folders.createFolder('Parent');
    final child = await folders.createFolder('Child', parentId: parent.id);
    await folders.moveCharactersToFolder(['char-a'], folderId: child.id);
    await folders.moveCharactersToFolder(['char-b'], folderId: parent.id);

    final removed = await folders.deleteFolderTree(parent.id);
    expect(removed.toSet(), {'char-a', 'char-b'});
    expect(await folders.listAllFolders(), isEmpty);
    expect(await folders.folderIdForCharacter('char-a'), isNull);
    expect(await folders.folderIdForCharacter('char-b'), isNull);
  });
}
