import 'package:flutter/material.dart';

import 'package:native_tavern/data/models/persona.dart';

/// Colors for the moments feed. The page keeps its own light and dark surfaces
/// so a theme change still flips the feed, without borrowing chat bubble colors.
class MomentsPalette {
  const MomentsPalette._({required this.dark});

  factory MomentsPalette.of(BuildContext context) {
    return MomentsPalette._(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  final bool dark;

  static const onMedia = Colors.white;
  static const mediaShadow = Colors.black54;
  static const mediaScrim = Colors.black45;
  static const viewer = Colors.black;
  static const liked = Color(0xFFFA5151);
  static const send = Color(0xFF07C160);
  static const menu = Color(0xFF4C4C4C);
  static const avatarFill = Color(0xFFB7C4D6);
  static const avatarInitial = Color(0xFF8FA4C2);
  static const coverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2B3340),
      Color(0xFF6B5344),
      Color(0xFF8A6A4A),
    ],
  );

  static Color get sendDisabled => send.withValues(alpha: 0.35);

  static Color get onSendDisabled => onMedia.withValues(alpha: 0.7);

  Color get page => dark ? const Color(0xFF111111) : const Color(0xFFEDEDED);
  Color get cell => dark ? const Color(0xFF191919) : Colors.white;
  Color get name => const Color(0xFF576B95);
  Color get text => dark ? const Color(0xFFEDEDED) : const Color(0xFF111111);
  Color get time => const Color(0xFF888888);
  Color get commentBox =>
      dark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7);
  Color get divider => dark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E5);
}

String momentsPersonaName(Persona? persona, String fallback) {
  final name = persona?.name.trim();
  if (name == null || name.isEmpty) return fallback;
  return name;
}
