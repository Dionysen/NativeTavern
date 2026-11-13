import 'package:flutter/material.dart';
import 'package:native_tavern/data/models/tag.dart';

extension TagColor on Tag {
  /// Parsed display color. Invalid or empty stored strings read as grey.
  Color get colorValue {
    if (color == null || color!.isEmpty) {
      return Colors.grey;
    }
    try {
      final hex = color!.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return Colors.grey;
  }
}

/// Preset swatches for tag editing. Stored values stay hex strings on [Tag].
abstract final class TagColors {
  static const presetColors = <Color>[
    Color(0xFFE57373),
    Color(0xFFFF8A65),
    Color(0xFFFFB74D),
    Color(0xFFFFD54F),
    Color(0xFFFFF176),
    Color(0xFFDCE775),
    Color(0xFFAED581),
    Color(0xFF81C784),
    Color(0xFF4DB6AC),
    Color(0xFF4DD0E1),
    Color(0xFF4FC3F7),
    Color(0xFF64B5F6),
    Color(0xFF7986CB),
    Color(0xFF9575CD),
    Color(0xFFBA68C8),
    Color(0xFFF06292),
    Color(0xFF90A4AE),
    Color(0xFFA1887F),
  ];

  static Color getRandomColor() {
    return presetColors[DateTime.now().millisecond % presetColors.length];
  }

  /// Stable color for a free-form label (e.g. character.tags strings).
  static Color forLabel(String label) {
    if (label.isEmpty) return presetColors.last;
    return presetColors[label.hashCode.abs() % presetColors.length];
  }

  static String colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }
}
