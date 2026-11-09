import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/models/chat.dart' as models;
import 'package:native_tavern/data/repositories/chat_repository.dart';
import 'package:native_tavern/data/repositories/group_repository.dart';

void main() {
  late AppDatabase database;
  late ChatRepository chats;
  late GroupRepository groups;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    chats = ChatRepository(database);
    groups = GroupRepository(database);
    final now = DateTime.now();
    await database.into(database.characters).insert(
          CharactersCompanion.insert(
            id: 'ava',
            name: 'Ava',
            createdAt: now,
            modifiedAt: now,
          ),
        );
    await database.into(database.characters).insert(
          CharactersCompanion.insert(
            id: 'leo',
            name: 'Leo',
            createdAt: now,
            modifiedAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('search matches title, character name, group name, and author note',
      () async {
    await chats.createChat(
      models.Chat(
        id: 'by-title',
        characterId: 'leo',
        title: 'Garden notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await chats.createChat(
      models.Chat(
        id: 'by-name',
        characterId: 'ava',
        title: 'New Chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await chats.createChat(
      models.Chat(
        id: 'by-note',
        characterId: 'leo',
        title: 'Untitled',
        authorNote: 'spare key under the pot',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final group = await groups.createGroup(name: 'Night market');
    await chats.createChat(
      models.Chat(
        id: 'by-group',
        characterId: 'leo',
        groupId: group.id,
        title: 'Group',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      (await chats.getChatsPage(query: 'garden')).map((chat) => chat.id),
      ['by-title'],
    );
    expect(
      (await chats.getChatsPage(query: 'Ava')).map((chat) => chat.id),
      ['by-name'],
    );
    expect(
      (await chats.getChatsPage(query: 'spare key')).map((chat) => chat.id),
      ['by-note'],
    );
    expect(
      (await chats.getChatsPage(query: 'market')).map((chat) => chat.id),
      ['by-group'],
    );
    expect(await chats.getChatsPage(query: 'missing'), isEmpty);
  });

  test('search treats percent and underscore as literal characters', () async {
    await chats.createChat(
      models.Chat(
        id: 'percent',
        characterId: 'ava',
        title: '100%',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await chats.createChat(
      models.Chat(
        id: 'plain',
        characterId: 'leo',
        title: 'Plain talk',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      (await chats.getChatsPage(query: '%')).map((chat) => chat.id),
      ['percent'],
    );
    expect(
      (await chats.getChatsPage(query: '100%')).map((chat) => chat.id),
      ['percent'],
    );
  });
}
