import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/bookmark.dart';

void main() {
  test('Bookmark json keeps the checkpoint and copyWith can clear the note', () {
    final created = DateTime.utc(2026, 5, 6, 7, 8);
    final bookmark = Bookmark(
      id: 'b1',
      chatId: 'chat',
      name: 'Before the door',
      description: 'A quiet hall',
      messageId: 'm4',
      messageIndex: 3,
      createdAt: created,
    );

    final restored = Bookmark.fromJson(bookmark.toJson());
    expect(restored.messageId, 'm4');
    expect(restored.messageIndex, 3);
    expect(restored.description, 'A quiet hall');
    expect(restored.createdAt, created);

    final cleared = bookmark.copyWith(clearDescription: true, name: 'Later');
    expect(cleared.description, isNull);
    expect(cleared.name, 'Later');
    expect(cleared.messageIndex, 3);
  });
}
