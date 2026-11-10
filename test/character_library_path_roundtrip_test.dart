import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/models/character.dart' as models;
import 'package:native_tavern/data/repositories/character_folder_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/world_info_repository.dart';
import 'package:native_tavern/domain/services/character_card_export_service.dart';
import 'package:native_tavern/domain/services/character_library_export_service.dart';
import 'package:native_tavern/domain/services/character_library_import_service.dart';
import 'package:native_tavern/domain/services/import_service.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase database;
  late CharacterFolderRepository folders;
  late CharacterRepository characters;
  late ImportService importService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nt_library_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    final dataPath = p.join(tempDir.path, 'NativeTavern');
    await Directory(dataPath).create(recursive: true);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    folders = CharacterFolderRepository(database);
    characters = CharacterRepository(database, dataPath);
    importService = ImportService(dataPath);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('export then import restores folder path', () async {
    final leafId = await folders.ensureFolderPath(['Fantasy', 'Elves']);
    final created = await characters.createCharacter(
      models.Character(
        id: '',
        name: 'Elf Scout',
        description: 'A scout',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );
    await folders.moveCharactersToFolder([created.id], folderId: leafId);

    final exportRoot = Directory(p.join(tempDir.path, 'export'));
    final exportService = CharacterLibraryExportService(
      characterRepository: characters,
      folderRepository: folders,
      exportService: CharacterCardExportService(importService),
    );
    final exportResult = await exportService.exportToDirectory(exportRoot.path);
    expect(exportResult.succeeded, 1);
    expect(
      File(p.join(exportRoot.path, 'Fantasy', 'Elves', 'Elf Scout.png'))
          .existsSync(),
      isTrue,
    );

    await database.close();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    folders = CharacterFolderRepository(database);
    characters = CharacterRepository(
      database,
      p.join(tempDir.path, 'NativeTavern'),
    );
    final worldInfo = WorldInfoRepository(database);
    final importLibrary = CharacterLibraryImportService(
      importService: importService,
      characterRepository: characters,
      folderRepository: folders,
      worldInfoRepository: worldInfo,
      importEmbeddedRegex: (_, __) async {},
    );

    final importResult =
        await importLibrary.importFromDirectory(exportRoot.path);
    expect(
      importResult.errors,
      isEmpty,
      reason: importResult.errors.join('\n'),
    );
    expect(importResult.succeeded, 1);

    final rootFolders = await folders.listFolders();
    expect(rootFolders.single.name, 'Fantasy');
    final child =
        (await folders.listFolders(parentId: rootFolders.single.id)).single;
    expect(child.name, 'Elves');
    final all = await characters.getAllCharacters();
    expect(all.single.name, 'Elf Scout');
    expect(await folders.folderIdForCharacter(all.single.id), child.id);
  });

  test('folder import brings in standalone world-info JSON', () async {
    final importRoot = Directory(p.join(tempDir.path, 'mixed_import'));
    final loreDir = Directory(p.join(importRoot.path, 'Lore'));
    await loreDir.create(recursive: true);

    await File(p.join(importRoot.path, 'Scout.json')).writeAsString(
      jsonEncode({
        'spec': 'chara_card_v3',
        'spec_version': '3.0',
        'data': {
          'name': 'Scout',
          'description': 'A scout',
          'first_mes': 'Hello',
        },
      }),
    );
    await File('test/fixtures/Eldoria.json')
        .copy(p.join(loreDir.path, 'Eldoria.json'));

    final worldInfo = WorldInfoRepository(database);
    final importLibrary = CharacterLibraryImportService(
      importService: importService,
      characterRepository: characters,
      folderRepository: folders,
      worldInfoRepository: worldInfo,
      importEmbeddedRegex: (_, __) async {},
    );

    final result = await importLibrary.importFromDirectory(importRoot.path);
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(result.succeeded, 2);
    expect(result.failed, 0);

    final allCharacters = await characters.getAllCharacters();
    expect(allCharacters.map((c) => c.name), ['Scout']);

    final books = await worldInfo.getAllWorldInfos();
    expect(books, hasLength(1));
    expect(books.single.name, 'Eldoria');
    expect(books.single.entries, isNotEmpty);
    expect(
      books.single.entries.any((e) => e.keys.contains('eldoria')),
      isTrue,
    );
  });
}
