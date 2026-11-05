import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/repositories/character_folder_repository.dart';

void main() {
  late AppDatabase database;
  late CharacterFolderRepository folders;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    folders = CharacterFolderRepository(database);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.customStatement(
      'INSERT INTO characters (id, name, description, personality, scenario, '
      'first_mes, mes_example, creator, character_version, tags, extensions_json, '
      'is_favorite, is_deleted, created_at, modified_at) '
      "VALUES ('char-a', 'A', '', '', '', '', '', '', '', '[]', '{}', 0, 0, ?, ?)",
      [now, now],
    );
    await database.customStatement(
      'INSERT INTO characters (id, name, description, personality, scenario, '
      'first_mes, mes_example, creator, character_version, tags, extensions_json, '
      'is_favorite, is_deleted, created_at, modified_at) '
      "VALUES ('char-b', 'B', '', '', '', '', '', '', '', '[]', '{}', 0, 0, ?, ?)",
      [now, now],
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('creates folder, moves characters, and dissolves', () async {
    final folder = await folders.createFolder('Favorites');
    expect(folder.name, 'Favorites');

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
}
