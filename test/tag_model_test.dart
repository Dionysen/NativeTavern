import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/tag.dart';

void main() {
  group('Tag', () {
    test('parses hex colors and falls back to grey', () {
      final tagged = Tag(
        id: 't1',
        name: 'Fantasy',
        color: '#E57373',
        createdAt: DateTime.utc(2026),
      );
      expect(tagged.colorValue, const Color(0xFFE57373));

      final withAlpha = tagged.copyWith(color: '80E57373');
      expect(withAlpha.colorValue, const Color(0x80E57373));
      expect(tagged.copyWith(color: 'nope').colorValue, Colors.grey);
      expect(
        Tag(
          id: 'empty',
          name: 'Empty',
          createdAt: DateTime.utc(2026),
        ).colorValue,
        Colors.grey,
      );
    });

    test('colorToHex drops the alpha byte and json keeps the stored string', () {
      expect(Tag.colorToHex(const Color(0xFFE57373)), '#E57373');

      final tag = Tag(
        id: 't1',
        name: 'Fantasy',
        color: '#E57373',
        icon: 'book',
        createdAt: DateTime.utc(2026, 3, 4),
      );
      final restored = Tag.fromJson(tag.toJson());
      expect(restored.name, 'Fantasy');
      expect(restored.color, '#E57373');
      expect(restored.icon, 'book');
      expect(restored.createdAt, DateTime.utc(2026, 3, 4));
      expect(restored, tag);
    });
  });

  group('TagColors', () {
    test('the same label always maps to the same preset', () {
      expect(TagColors.forLabel(''), TagColors.presetColors.last);
      expect(TagColors.forLabel('fantasy'), TagColors.forLabel('fantasy'));
      expect(TagColors.presetColors, contains(TagColors.forLabel('fantasy')));
    });
  });
}
