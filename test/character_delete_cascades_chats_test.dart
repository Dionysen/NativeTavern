import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/data/models/character.dart' as models;
import 'package:native_tavern/data/models/chat.dart' as models;
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late Directory dataDirectory;
  late CharacterRepository characterRepository;
  late ChatRepository chatRepository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dataDirectory =
        Directory.systemTemp.createTempSync('nt_character_delete_chats');
    characterRepository = CharacterRepository(database, dataDirectory.path);
    chatRepository = ChatRepository(database);

    final now = DateTime.now();
    await characterRepository.createCharacter(models.Character(
      id: 'char-a',
      name: 'Alice',
      description: 'Solo chats should be removed with the card.',
      createdAt: now,
      modifiedAt: now,
    ));
    await characterRepository.createCharacter(models.Character(
      id: 'char-b',
      name: 'Bob',
      description: 'Other character chats must stay.',
      createdAt: now,
      modifiedAt: now,
    ));
  });

  tearDown(() async {
    await database.close();
    dataDirectory.deleteSync(recursive: true);
  });

  test('deleteCharacter removes 1:1 chats and keeps group chats', () async {
    final now = DateTime.now();
    final solo = await chatRepository.createChat(models.Chat(
      id: 'chat-solo',
      characterId: 'char-a',
      title: 'Alice solo',
      createdAt: now,
      updatedAt: now,
    ));
    await chatRepository.addMessage(models.ChatMessage(
      id: 'msg-1',
      chatId: solo.id,
      role: models.MessageRole.user,
      content: 'hello',
      timestamp: now,
    ));

    final otherSolo = await chatRepository.createChat(models.Chat(
      id: 'chat-other',
      characterId: 'char-b',
      title: 'Bob solo',
      createdAt: now,
      updatedAt: now,
    ));

    final groupChat = await chatRepository.createChat(models.Chat(
      id: 'chat-group',
      characterId: 'char-a',
      groupId: 'group-1',
      title: 'Group with Alice',
      createdAt: now,
      updatedAt: now,
    ));

    await characterRepository.deleteCharacter('char-a');

    final deleted = await characterRepository.getCharacter('char-a');
    expect(deleted, isNotNull);
    expect(deleted!.isDeleted, isTrue);
    expect(
      (await characterRepository.getAllCharacters())
          .any((c) => c.id == 'char-a'),
      isFalse,
    );
    expect(await chatRepository.getChat(solo.id), isNull);
    expect(await chatRepository.getMessages(solo.id), isEmpty);
    expect(await chatRepository.getChat(otherSolo.id), isNotNull);
    expect(await chatRepository.getChat(groupChat.id), isNotNull);

    final remainingForA = await chatRepository.getChatsForCharacter('char-a');
    expect(remainingForA, isEmpty);
  });
}
