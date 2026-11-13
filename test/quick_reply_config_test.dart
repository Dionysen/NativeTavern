import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/quick_reply.dart';

void main() {
  QuickReply reply(String id, int order, {bool enabled = true, String? message}) {
    return QuickReply(
      id: id,
      label: id,
      message: message ?? id,
      order: order,
      enabled: enabled,
    );
  }

  group('QuickReplyConfig', () {
    test('enabled replies are returned in order', () {
      final config = QuickReplyConfig(replies: [
        reply('c', 2),
        reply('a', 0, enabled: false),
        reply('b', 1),
      ]);

      expect(config.enabledReplies.map((item) => item.id), ['b', 'c']);
    });

    test('add, update, toggle, and remove keep the other replies', () {
      var config = const QuickReplyConfig();
      config = config.addReply(reply('yes', 0, message: 'Yes'));
      config = config.updateReply(reply('yes', 0, message: 'Yep'));
      config = config.toggleReply('yes');
      expect(config.replies.single.message, 'Yep');
      expect(config.replies.single.enabled, isFalse);

      config = config.removeReply('yes');
      expect(config.replies, isEmpty);
    });

    test('reorder rewrites order from the sorted list', () {
      final config = QuickReplyConfig(replies: [
        reply('a', 0),
        reply('b', 1),
        reply('c', 2),
      ]).reorder(0, 2);

      expect(config.replies.map((item) => item.id), ['b', 'c', 'a']);
      expect(config.replies.map((item) => item.order), [0, 1, 2]);
    });

    test('json keeps visibility and a disabled reply', () {
      final config = QuickReplyConfig(
        showQuickReplies: false,
        showAboveInput: false,
        replies: [reply('no', 1, enabled: false)],
      );

      final restored = QuickReplyConfig.fromJsonString(config.toJsonString());
      expect(restored.showQuickReplies, isFalse);
      expect(restored.showAboveInput, isFalse);
      expect(restored.replies.single.enabled, isFalse);
      expect(QuickReplyConfig.defaultConfig.replies, isNotEmpty);
    });
  });
}
