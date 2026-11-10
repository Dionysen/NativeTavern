import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/domain/services/macro_service.dart';

void main() {
  ChatMessage message({
    required String id,
    required MessageRole role,
    required String content,
    bool generatedImage = false,
  }) {
    return ChatMessage(
      id: id,
      chatId: 'chat',
      role: role,
      content: content,
      timestamp: DateTime.utc(2026, 1, 1),
      metadata: generatedImage
          ? const {ChatMessage.generatedImageMetadataKey: true}
          : const {},
    );
  }

  test('picture replies are left out of spoken history', () {
    final messages = [
      message(id: '1', role: MessageRole.user, content: 'hello'),
      message(id: '2', role: MessageRole.assistant, content: 'she smiles'),
      message(
        id: '3',
        role: MessageRole.assistant,
        content: '1girl, smile',
        generatedImage: true,
      ),
    ];

    final spoken = withoutGeneratedImages(messages);
    expect(spoken.map((item) => item.id), ['1', '2']);
    expect(lastCharacterTextReply(messages)?.content, 'she smiles');

    final macros = MacroContext.fromData(messages: messages);
    expect(macros.lastMessage, 'she smiles');
    expect(macros.lastCharacterMessage, 'she smiles');
    expect(macros.lastUserMessage, 'hello');
  });
}
