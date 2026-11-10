/// Summary record for compressed chat history
class ChatSummary {
  final String id;
  final String content; // Summarized content
  final int
      endMessageIndex; // Index of the last message included in this summary
  final DateTime createdAt;

  const ChatSummary({
    required this.id,
    required this.content,
    required this.endMessageIndex,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'endMessageIndex': endMessageIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatSummary.fromJson(Map<String, dynamic> json) => ChatSummary(
        id: json['id'] as String,
        content: json['content'] as String,
        endMessageIndex: json['endMessageIndex'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Chat session model
class Chat {
  final String id;
  final String characterId;
  final String? groupId; // For group chats
  final String title;
  final String authorNote; // Author's Note content
  final int authorNoteDepth; // Depth for injection (messages from end)
  final bool authorNoteEnabled; // Whether Author's Note is active
  final List<ChatSummary>
      summaries; // History summaries for context compression

  /// Per-chat settings (persisted as JSON):
  /// startReplyWith, linkedWorldInfoIds, momentsInChat, ...
  final Map<String, dynamic> settings;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Chat({
    required this.id,
    required this.characterId,
    this.groupId,
    required this.title,
    this.authorNote = '',
    this.authorNoteDepth = 4,
    this.authorNoteEnabled = false,
    this.summaries = const [],
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if this is a group chat
  bool get isGroupChat => groupId != null;

  /// Text the AI reply should start with (assistant prefill / ST's
  /// "Start Reply With")
  String get startReplyWith => settings['startReplyWith'] as String? ?? '';

  /// World info books linked to this chat (in addition to global and
  /// character-linked books)
  List<String> get linkedWorldInfoIds =>
      (settings['linkedWorldInfoIds'] as List<dynamic>?)?.cast<String>() ??
      const [];

  /// When true, this chat may inject visible moments into the prompt.
  /// Defaults to off so existing character-card play stays unchanged.
  bool get momentsInChat => settings['momentsInChat'] == true;

  /// Copy with an updated settings entry
  Chat withSetting(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(settings);
    if (value == null) {
      updated.remove(key);
    } else {
      updated[key] = value;
    }
    return copyWith(settings: updated);
  }

  Chat copyWith({
    String? id,
    String? characterId,
    String? groupId,
    bool clearGroupId = false,
    String? title,
    String? authorNote,
    int? authorNoteDepth,
    bool? authorNoteEnabled,
    List<ChatSummary>? summaries,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chat(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      title: title ?? this.title,
      authorNote: authorNote ?? this.authorNote,
      authorNoteDepth: authorNoteDepth ?? this.authorNoteDepth,
      authorNoteEnabled: authorNoteEnabled ?? this.authorNoteEnabled,
      summaries: summaries ?? this.summaries,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'characterId': characterId,
        'groupId': groupId,
        'title': title,
        'authorNote': authorNote,
        'authorNoteDepth': authorNoteDepth,
        'authorNoteEnabled': authorNoteEnabled,
        'summaries': summaries.map((s) => s.toJson()).toList(),
        'settings': settings,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
        id: json['id'] as String,
        characterId: json['characterId'] as String,
        groupId: json['groupId'] as String?,
        title: json['title'] as String? ?? 'New Chat',
        authorNote: json['authorNote'] as String? ?? '',
        authorNoteDepth: json['authorNoteDepth'] as int? ?? 4,
        authorNoteEnabled: json['authorNoteEnabled'] as bool? ?? false,
        summaries: (json['summaries'] as List<dynamic>?)
                ?.map((s) => ChatSummary.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        settings: json['settings'] as Map<String, dynamic>? ?? const {},
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// Message role enum
enum MessageRole { user, assistant, system }

/// Image attachment for chat messages
class ChatAttachment {
  final String id;
  final String path; // Local file path
  final String? mimeType;
  final int? width;
  final int? height;
  final int? sizeBytes;

  const ChatAttachment({
    required this.id,
    required this.path,
    this.mimeType,
    this.width,
    this.height,
    this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        if (mimeType != null) 'mimeType': mimeType,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        id: json['id'] as String,
        path: json['path'] as String,
        mimeType: json['mimeType'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        sizeBytes: json['sizeBytes'] as int?,
      );
}

/// Chat message model
class ChatMessage {
  /// Metadata flag for a picture the character posted.
  ///
  /// Text generation skips these messages so the picture prompt is not part
  /// of the next reply.
  static const generatedImageMetadataKey = 'generatedImage';

  /// Layout for a generated-image-only bubble (`attach` vs default separate).
  static const generatedImageLayoutMetadataKey = 'generatedImageLayout';
  static const generatedImageLayoutAttach = 'attach';

  /// True while an image is still generating for this message (placeholder).
  static const pendingImageGenMetadataKey = 'pendingImageGen';

  /// Optional aspect ratio (width/height) for the pending placeholder tile.
  static const pendingImageGenAspectMetadataKey = 'pendingImageGenAspect';

  /// How many placeholder tiles are still generating (attach multi-image strip).
  static const pendingImageGenCountMetadataKey = 'pendingImageGenCount';

  final String id;
  final String chatId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<String> swipes;
  final int currentSwipeIndex;
  final String?
      characterId; // For group chats - which character sent this message
  final String? characterName; // Cached character name for display
  final String? reasoning; // Chain of Thought / Thinking content from LLM
  final List<String>? reasoningSwipes; // Reasoning content for each swipe
  final List<ChatAttachment> attachments; // Image attachments
  final Map<String, dynamic> metadata;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.swipes = const [],
    this.currentSwipeIndex = 0,
    this.characterId,
    this.characterName,
    this.reasoning,
    this.reasoningSwipes,
    this.attachments = const [],
    this.metadata = const {},
  });

  /// Get the current reasoning content (for current swipe)
  String? get currentReasoning {
    if (reasoningSwipes != null &&
        currentSwipeIndex >= 0 &&
        currentSwipeIndex < reasoningSwipes!.length) {
      return reasoningSwipes![currentSwipeIndex];
    }
    return reasoning;
  }

  /// Check if this message has reasoning/thinking content
  bool get hasReasoning =>
      (reasoning != null && reasoning!.isNotEmpty) ||
      (reasoningSwipes != null && reasoningSwipes!.any((r) => r.isNotEmpty));

  /// Check if this message has image attachments
  bool get hasAttachments => attachments.isNotEmpty;

  /// A picture posted as the character's own reply.
  bool get isGeneratedImage => metadata[generatedImageMetadataKey] == true;

  /// Generated pictures shown attached inside a padded bubble (not edge-to-edge).
  bool get isAttachedGeneratedImage =>
      isGeneratedImage &&
      metadata[generatedImageLayoutMetadataKey] == generatedImageLayoutAttach;

  /// Image generation placeholder is still running for this message.
  bool get isPendingImageGen => metadata[pendingImageGenMetadataKey] == true;

  /// Aspect ratio hint for a pending image placeholder (defaults to square).
  double get pendingImageGenAspect {
    final raw = metadata[pendingImageGenAspectMetadataKey];
    if (raw is num && raw > 0) return raw.toDouble();
    return 1.0;
  }

  /// Remaining placeholder slots while images are generating (defaults to 1).
  int get pendingImageGenCount {
    final raw = metadata[pendingImageGenCountMetadataKey];
    if (raw is num && raw > 0) return raw.round().clamp(1, 4);
    return isPendingImageGen ? 1 : 0;
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    List<String>? swipes,
    int? currentSwipeIndex,
    String? characterId,
    String? characterName,
    String? reasoning,
    List<String>? reasoningSwipes,
    List<ChatAttachment>? attachments,
    Map<String, dynamic>? metadata,
    bool clearCharacterId = false,
    bool clearCharacterName = false,
    bool clearReasoning = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      swipes: swipes ?? this.swipes,
      currentSwipeIndex: currentSwipeIndex ?? this.currentSwipeIndex,
      characterId: clearCharacterId ? null : (characterId ?? this.characterId),
      characterName:
          clearCharacterName ? null : (characterName ?? this.characterName),
      reasoning: clearReasoning ? null : (reasoning ?? this.reasoning),
      reasoningSwipes:
          clearReasoning ? null : (reasoningSwipes ?? this.reasoningSwipes),
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'swipes': swipes,
        'currentSwipeIndex': currentSwipeIndex,
        'characterId': characterId,
        'characterName': characterName,
        if (reasoning != null) 'reasoning': reasoning,
        if (reasoningSwipes != null) 'reasoningSwipes': reasoningSwipes,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        chatId: json['chatId'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => MessageRole.user,
        ),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        swipes: (json['swipes'] as List<dynamic>?)?.cast<String>() ?? [],
        currentSwipeIndex: json['currentSwipeIndex'] as int? ?? 0,
        characterId: json['characterId'] as String?,
        characterName: json['characterName'] as String?,
        reasoning: json['reasoning'] as String?,
        reasoningSwipes:
            (json['reasoningSwipes'] as List<dynamic>?)?.cast<String>(),
        attachments: (json['attachments'] as List<dynamic>?)
                ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );
}

/// Messages that should be spoken to the text model.
List<ChatMessage> withoutGeneratedImages(List<ChatMessage> messages) {
  return [
    for (final message in messages)
      if (!message.isGeneratedImage) message,
  ];
}

/// Latest character line that is dialogue, not a generated picture.
ChatMessage? lastCharacterTextReply(List<ChatMessage> messages) {
  for (final message in messages.reversed) {
    if (message.role == MessageRole.assistant &&
        !message.isGeneratedImage &&
        message.content.trim().isNotEmpty) {
      return message;
    }
  }
  return null;
}
