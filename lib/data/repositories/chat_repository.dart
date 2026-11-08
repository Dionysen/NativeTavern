import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/database/database.dart' hide Chat, Message;
import 'package:native_tavern/data/database/database.dart' as db;
import 'package:native_tavern/data/models/chat.dart' as models;
import 'package:uuid/uuid.dart';

/// Provider for chat repository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Repository for managing chat data
class ChatRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ChatRepository(this._db);

  /// Get all chats
  Future<List<models.Chat>> getAllChats() async {
    final rows = await (_db.select(
      _db.chats,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  /// Loads a bounded page for the home chat list.
  Future<List<models.Chat>> getChatsPage({
    int limit = 40,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.chats)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset < 0 ? 0 : offset))
        .get();
    return rows.map(_chatFromRow).toList(growable: false);
  }

  /// Get chats for a specific character
  Future<List<models.Chat>> getChatsForCharacter(String characterId) async {
    final rows = await (_db.select(_db.chats)
          ..where((t) => t.characterId.equals(characterId) & t.groupId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  /// Get recent chats
  Future<List<models.Chat>> getRecentChats({int limit = 10}) async {
    final rows = await (_db.select(_db.chats)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  /// Get chat by ID
  Future<models.Chat?> getChat(String id) async {
    final row = await (_db.select(
      _db.chats,
    )..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _chatFromRow(row) : null;
  }

  /// Create a new chat
  Future<models.Chat> createChat(models.Chat chat) async {
    final id = chat.id.isEmpty ? _uuid.v4() : chat.id;
    final now = DateTime.now();

    final newChat = models.Chat(
      id: id,
      characterId: chat.characterId,
      groupId: chat.groupId,
      title: chat.title,
      authorNote: chat.authorNote,
      authorNoteDepth: chat.authorNoteDepth,
      authorNoteEnabled: chat.authorNoteEnabled,
      summaries: chat.summaries,
      settings: chat.settings,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.chats).insert(
          ChatsCompanion(
            id: Value(newChat.id),
            characterId: Value(newChat.characterId),
            groupId: Value(newChat.groupId),
            title: Value(newChat.title),
            authorNote: Value(newChat.authorNote),
            authorNoteDepth: Value(newChat.authorNoteDepth),
            authorNoteEnabled: Value(newChat.authorNoteEnabled),
            settingsJson: Value(_encodeSettings(newChat)),
            createdAt: Value(newChat.createdAt),
            updatedAt: Value(newChat.updatedAt),
          ),
        );

    return newChat;
  }

  /// Update chat
  Future<models.Chat> updateChat(models.Chat chat) async {
    final now = DateTime.now();

    await (_db.update(_db.chats)..where((t) => t.id.equals(chat.id))).write(
      ChatsCompanion(
        title: Value(chat.title),
        authorNote: Value(chat.authorNote),
        authorNoteDepth: Value(chat.authorNoteDepth),
        authorNoteEnabled: Value(chat.authorNoteEnabled),
        settingsJson: Value(_encodeSettings(chat)),
        updatedAt: Value(now),
      ),
    );

    return chat.copyWith(updatedAt: now);
  }

  /// Delete chat and all its messages
  Future<void> deleteChat(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.bookmarks)..where((t) => t.chatId.equals(id))).go();
      await (_db.delete(_db.messages)..where((t) => t.chatId.equals(id))).go();
      await (_db.delete(_db.chats)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Delete all 1:1 chats for [characterId] (skips group chats).
  Future<void> deleteChatsForCharacter(String characterId) async {
    final chats = await getChatsForCharacter(characterId);
    for (final chat in chats) {
      await deleteChat(chat.id);
    }
  }

  /// Get messages for a chat
  Future<List<models.ChatMessage>> getMessages(String chatId) async {
    final rows = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.timestamp),
            (t) => OrderingTerm.asc(t.rowId),
          ]))
        .get();
    return rows.map(_messageFromRow).toList();
  }

  /// Load a bounded page of messages, keeping chronological order.
  ///
  /// Pages are addressed from the newest message: offset 0 returns the most
  /// recent page, while larger offsets load progressively older messages.
  Future<List<models.ChatMessage>> getMessagesPage(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0) return const [];
    final rows = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.desc(t.rowId),
          ])
          ..limit(limit, offset: offset < 0 ? 0 : offset))
        .get();
    return rows.reversed.map(_messageFromRow).toList(growable: false);
  }

  /// Add a message to a chat
  Future<models.ChatMessage> addMessage(models.ChatMessage message) async {
    final id = message.id.isEmpty ? _uuid.v4() : message.id;

    final newMessage = message.copyWith(id: id);

    await _db.into(_db.messages).insert(
          MessagesCompanion(
            id: Value(newMessage.id),
            chatId: Value(newMessage.chatId),
            role: Value(newMessage.role.name),
            content: Value(newMessage.content),
            timestamp: Value(newMessage.timestamp),
            swipes: Value(jsonEncode(newMessage.swipes)),
            currentSwipeIndex: Value(newMessage.currentSwipeIndex),
            characterId: Value(newMessage.characterId),
            characterName: Value(newMessage.characterName),
            metadataJson: Value(_encodeMessageMetadata(newMessage)),
            attachmentsJson: Value(
              jsonEncode(
                newMessage.attachments.map((a) => a.toJson()).toList(),
              ),
            ),
          ),
        );

    // Update chat's updatedAt
    await (_db.update(_db.chats)..where((t) => t.id.equals(message.chatId)))
        .write(ChatsCompanion(updatedAt: Value(DateTime.now())));

    return newMessage;
  }

  /// Update a message
  Future<models.ChatMessage> updateMessage(models.ChatMessage message) async {
    await (_db.update(
      _db.messages,
    )..where((t) => t.id.equals(message.id)))
        .write(
      MessagesCompanion(
        content: Value(message.content),
        swipes: Value(jsonEncode(message.swipes)),
        currentSwipeIndex: Value(message.currentSwipeIndex),
        characterId: Value(message.characterId),
        characterName: Value(message.characterName),
        metadataJson: Value(_encodeMessageMetadata(message)),
        attachmentsJson: Value(
          jsonEncode(message.attachments.map((a) => a.toJson()).toList()),
        ),
      ),
    );

    // Update chat's updatedAt
    await (_db.update(_db.chats)..where((t) => t.id.equals(message.chatId)))
        .write(ChatsCompanion(updatedAt: Value(DateTime.now())));

    return message;
  }

  /// Delete a message
  Future<void> deleteMessage(String id) async {
    await (_db.delete(_db.messages)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all messages and message-dependent data while keeping the chat.
  Future<void> clearMessages(String chatId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.bookmarks,
      )..where((t) => t.chatId.equals(chatId)))
          .go();
      await (_db.delete(
        _db.messages,
      )..where((t) => t.chatId.equals(chatId)))
          .go();
      await (_db.update(_db.chats)..where((t) => t.id.equals(chatId))).write(
        ChatsCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  /// Get message count for a chat
  Future<int> getMessageCount(String chatId) async {
    final countExpression = _db.messages.id.count();
    final row = await (_db.selectOnly(_db.messages)
          ..addColumns([countExpression])
          ..where(_db.messages.chatId.equals(chatId)))
        .getSingle();
    return row.read(countExpression) ?? 0;
  }

  /// Message count and approximate DB storage for home/list tiles.
  Future<ChatListStats> getChatListStats(String chatId) async {
    final row = await _db.customSelect(
      '''
      SELECT
        COUNT(*) AS message_count,
        COALESCE(
          SUM(
            LENGTH(CAST(content AS BLOB))
            + LENGTH(CAST(swipes AS BLOB))
            + LENGTH(CAST(metadata_json AS BLOB))
            + LENGTH(CAST(attachments_json AS BLOB))
          ),
          0
        ) AS storage_bytes
      FROM messages
      WHERE chat_id = ?
      ''',
      variables: [Variable<String>(chatId)],
      readsFrom: {_db.messages},
    ).getSingle();
    return ChatListStats(
      messageCount: row.read<int>('message_count'),
      storageBytes: row.read<int>('storage_bytes'),
    );
  }

  /// Total messages across all chats (for app statistics).
  Future<int> getTotalMessageCount() async {
    final countExpression = _db.messages.id.count();
    final row = await (_db.selectOnly(_db.messages)
          ..addColumns([countExpression]))
        .getSingle();
    return row.read(countExpression) ?? 0;
  }

  /// Get a single message by id.
  Future<models.ChatMessage?> getMessage(String messageId) async {
    final row = await (_db.select(_db.messages)
          ..where((t) => t.id.equals(messageId))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _messageFromRow(row) : null;
  }

  /// Get last message of a chat
  Future<models.ChatMessage?> getLastMessage(String chatId) async {
    final row = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _messageFromRow(row) : null;
  }

  /// Get chats for a group
  Future<List<models.Chat>> getChatsForGroup(String groupId) async {
    final rows = await (_db.select(_db.chats)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  // Private helpers

  models.Chat _chatFromRow(db.Chat row) {
    Map<String, dynamic> settings = const {};
    try {
      settings = jsonDecode(row.settingsJson) as Map<String, dynamic>;
    } catch (_) {
      // Keep empty settings on malformed JSON
    }
    return models.Chat(
      id: row.id,
      characterId: row.characterId,
      groupId: row.groupId,
      title: row.title,
      authorNote: row.authorNote,
      authorNoteDepth: row.authorNoteDepth,
      authorNoteEnabled: row.authorNoteEnabled,
      settings: settings,
      summaries: (settings['summaries'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(models.ChatSummary.fromJson)
              .toList() ??
          const [],
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _encodeSettings(models.Chat chat) {
    return jsonEncode({
      ...chat.settings,
      'summaries': chat.summaries.map((summary) => summary.toJson()).toList(),
    });
  }

  models.ChatMessage _messageFromRow(db.Message row) {
    final parsed = _decodeMessageMetadata(row.metadataJson);
    return models.ChatMessage(
      id: row.id,
      chatId: row.chatId,
      role: models.MessageRole.values.firstWhere(
        (r) => r.name == row.role,
        orElse: () => models.MessageRole.user,
      ),
      content: row.content,
      timestamp: row.timestamp,
      swipes: _parseJsonList(row.swipes),
      currentSwipeIndex: row.currentSwipeIndex,
      characterId: row.characterId,
      characterName: row.characterName,
      metadata: parsed.metadata,
      attachments: _parseAttachments(row.attachmentsJson),
      reasoning: parsed.reasoning,
      reasoningSwipes: parsed.reasoningSwipes,
    );
  }

  List<String> _parseJsonList(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  List<models.ChatAttachment> _parseAttachments(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map(
            (item) =>
                models.ChatAttachment.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _parseMetadata(String json) {
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return const {};
    }
  }

  /// Reserved metadata keys for persisting thinking without a schema bump.
  static const _reasoningKey = '__nt_reasoning';
  static const _reasoningSwipesKey = '__nt_reasoning_swipes';

  String _encodeMessageMetadata(models.ChatMessage message) {
    final map = Map<String, dynamic>.from(message.metadata);
    map.remove(_reasoningKey);
    map.remove(_reasoningSwipesKey);
    final reasoning = message.reasoning;
    if (reasoning != null && reasoning.isNotEmpty) {
      map[_reasoningKey] = reasoning;
    }
    final swipes = message.reasoningSwipes;
    if (swipes != null && swipes.isNotEmpty) {
      map[_reasoningSwipesKey] = swipes;
    }
    return jsonEncode(map);
  }

  ({
    Map<String, dynamic> metadata,
    String? reasoning,
    List<String>? reasoningSwipes,
  }) _decodeMessageMetadata(String json) {
    final map = _parseMetadata(json);
    final reasoningRaw = map.remove(_reasoningKey);
    final swipesRaw = map.remove(_reasoningSwipesKey);

    String? reasoning;
    if (reasoningRaw is String && reasoningRaw.isNotEmpty) {
      reasoning = reasoningRaw;
    }

    List<String>? reasoningSwipes;
    if (swipesRaw is List) {
      final parsed = swipesRaw.whereType<String>().toList();
      if (parsed.isNotEmpty) reasoningSwipes = parsed;
    }

    return (
      metadata: map,
      reasoning: reasoning,
      reasoningSwipes: reasoningSwipes,
    );
  }
}

/// Lightweight stats for chat list tiles.
class ChatListStats {
  final int messageCount;
  final int storageBytes;

  const ChatListStats({
    required this.messageCount,
    required this.storageBytes,
  });
}
