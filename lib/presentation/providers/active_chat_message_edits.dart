import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/data_bank_context.dart';

/// Edits the messages already on screen: swipes, text, attachments, deletes.
///
/// The notifier still owns generation and saving. This class only changes the
/// loaded message list and asks the notifier to persist each change.
class ActiveChatMessageEdits {
  ActiveChatMessageEdits({
    required List<ChatMessage> Function() readMessages,
    required String? Function() characterName,
    required void Function(List<ChatMessage> messages) writeMessages,
    required Future<void> Function(ChatMessage message) persistUpdate,
    required Future<void> Function(String messageId) persistDelete,
    required String Function(
      String content, {
      required MessageRole role,
      required String? characterName,
    }) persistEditedContent,
  })  : _readMessages = readMessages,
        _characterName = characterName,
        _writeMessages = writeMessages,
        _persistUpdate = persistUpdate,
        _persistDelete = persistDelete,
        _persistEditedContent = persistEditedContent;

  final List<ChatMessage> Function() _readMessages;
  final String? Function() _characterName;
  final void Function(List<ChatMessage> messages) _writeMessages;
  final Future<void> Function(ChatMessage message) _persistUpdate;
  final Future<void> Function(String messageId) _persistDelete;
  final String Function(
    String content, {
    required MessageRole role,
    required String? characterName,
  }) _persistEditedContent;

  List<ChatMessage> get _messages => _readMessages();

  Future<void> swipe(String messageId, int swipeIndex) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = _messages[messageIndex];
    if (swipeIndex < 0 || swipeIndex >= message.swipes.length) return;

    final updatedMessage = message.copyWith(
      content: message.swipes[swipeIndex],
      currentSwipeIndex: swipeIndex,
    );
    await _replaceAt(messageIndex, updatedMessage);
  }

  Future<void> deleteSwipe(String messageId, int swipeIndex) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = _messages[messageIndex];
    if (message.swipes.length <= 1) return;
    if (swipeIndex < 0 || swipeIndex >= message.swipes.length) return;

    final updatedSwipes = List<String>.from(message.swipes)
      ..removeAt(swipeIndex);

    var newIndex = message.currentSwipeIndex;
    if (newIndex >= updatedSwipes.length) {
      newIndex = updatedSwipes.length - 1;
    } else if (swipeIndex < newIndex) {
      newIndex--;
    }

    List<String>? updatedReasoningSwipes = message.reasoningSwipes;
    String? updatedReasoning = message.reasoning;
    var clearReasoning = false;
    if (message.reasoningSwipes != null) {
      final next = List<String>.from(message.reasoningSwipes!);
      if (swipeIndex < next.length) {
        next.removeAt(swipeIndex);
      }
      if (next.isEmpty) {
        updatedReasoningSwipes = null;
        updatedReasoning = null;
        clearReasoning = true;
      } else {
        updatedReasoningSwipes = next;
        updatedReasoning = newIndex < next.length ? next[newIndex] : next.last;
      }
    }

    final updatedMessage = message.copyWith(
      content: updatedSwipes[newIndex],
      swipes: updatedSwipes,
      currentSwipeIndex: newIndex,
      clearReasoning: clearReasoning,
      reasoning: updatedReasoning,
      reasoningSwipes: updatedReasoningSwipes,
      metadata: removeDataBankContextMetadataAt(
        metadata: message.metadata,
        swipeIndex: swipeIndex,
      ),
    );
    await _replaceAt(messageIndex, updatedMessage);
  }

  Future<void> edit(String messageId, String newContent) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = _messages[messageIndex];
    final persistedContent = _persistEditedContent(
      newContent,
      role: message.role,
      characterName: _characterName() ?? message.characterName,
    );
    final updatedSwipes = List<String>.from(message.swipes);
    updatedSwipes[message.currentSwipeIndex] = persistedContent;

    final updatedMessage = message.copyWith(
      content: persistedContent,
      swipes: updatedSwipes,
    );
    await _replaceAt(messageIndex, updatedMessage);
  }

  Future<void> delete(String messageId) async {
    await _persistDelete(messageId);
    _writeMessages(
      _messages.where((m) => m.id != messageId).toList(),
    );
  }

  Future<void> deleteFrom(String messageId) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final messagesToDelete = _messages.sublist(messageIndex);
    for (final msg in messagesToDelete) {
      await _persistDelete(msg.id);
    }
    _writeMessages(_messages.sublist(0, messageIndex));
  }

  Future<void> addAttachments(
    String messageId,
    List<ChatAttachment> attachments,
  ) async {
    if (attachments.isEmpty) return;
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = _messages[messageIndex];
    await patch(
      messageId,
      attachments: [...message.attachments, ...attachments],
    );
  }

  Future<void> patch(
    String messageId, {
    List<ChatAttachment>? attachments,
    Map<String, dynamic>? metadata,
  }) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = _messages[messageIndex];
    final updatedMessage = message.copyWith(
      attachments: attachments ?? message.attachments,
      metadata: metadata ?? message.metadata,
    );
    await _replaceAt(messageIndex, updatedMessage);
  }

  Future<void> _replaceAt(int index, ChatMessage message) async {
    await _persistUpdate(message);
    final updatedMessages = List<ChatMessage>.from(_messages);
    updatedMessages[index] = message;
    _writeMessages(updatedMessages);
  }
}
