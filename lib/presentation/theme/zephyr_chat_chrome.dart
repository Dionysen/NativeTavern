import 'package:flutter/material.dart';

import 'native_tavern_theme.dart';

/// Chat chrome ported from Zephyr's mobile AI assistant
/// (`workspace_ai_chat_view.dart` / `zephyr_chat_bubble_shape.dart`).
///
/// Colors always come from [ColorScheme]; shapes use continuous curves.
abstract final class ZephyrChatChrome {
  /// Near-pill outer radius used by Zephyr's floating composer.
  static const double composerOuterRadius = 50;

  /// Soft floating fill (lerp surface toward black/white).
  static Color composerFill(ColorScheme scheme, Brightness brightness) {
    return brightness == Brightness.dark
        ? Color.lerp(Colors.black, scheme.surface, 0.1)!
        : Color.lerp(Colors.white, scheme.surface, 0.06)!;
  }

  static List<BoxShadow> composerShadows(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.1);
    return [
      BoxShadow(
        color: color,
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Floating continuous-curve composer shell.
  static ShapeDecoration composerShell(BuildContext context) {
    final theme = Theme.of(context);
    return continuousRoundedDecoration(
      color: composerFill(theme.colorScheme, theme.brightness),
      radius: composerOuterRadius,
      shadows: composerShadows(theme.brightness),
    );
  }

  /// Borderless field inside the composer (Zephyr field-in-pill).
  static InputDecoration composerFieldDecoration(
    BuildContext context, {
    String? hintText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hintStyle = messageInputStyle(
      context,
      color: scheme.onSurfaceVariant,
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Bordered well for dialogs / search (not the chat composer).
  static InputDecoration inputFieldDecoration(
    BuildContext context, {
    String? hintText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final outline = scheme.outline;
    final focused = scheme.primary;
    final radius = BorderRadius.circular(context.appCornerRadius);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surface,
      border: border(outline),
      enabledBorder: border(outline),
      focusedBorder: border(focused, 1.5),
      disabledBorder: border(outline.withValues(alpha: 0.4)),
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static BoxDecoration inputMenuPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = context.appCornerRadius;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
      border:
          context.appShowBorders ? Border.all(color: scheme.outline) : null,
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: dark ? 0.18 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ],
    );
  }

  static BoxDecoration menuChip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(context.appCornerRadius),
      border: context.appShowBorders
          ? Border.all(color: scheme.outlineVariant)
          : null,
    );
  }

  /// Chip-shaped control with visible Material ink splash on tap.
  static Widget tappableMenuChip(
    BuildContext context, {
    required VoidCallback onTap,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final radius = BorderRadius.circular(context.appCornerRadius);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: menuChip(context),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        ),
      ),
    );
  }

  /// Continuous-curve pill / rounded rect (Zephyr composer chrome).
  static ShapeDecoration continuousRoundedDecoration({
    required Color color,
    required double radius,
    List<BoxShadow>? shadows,
  }) {
    final r = radius.clamp(0.0, 80.0);
    return ShapeDecoration(
      color: color,
      shadows: shadows,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  /// Sharp top-outer corner, continuous curve elsewhere (Zephyr bubbles).
  static BorderRadius bubbleBorderRadius({
    required bool isUser,
    required double radius,
  }) {
    final r = radius.clamp(0.0, 80.0);
    return BorderRadius.only(
      topLeft: Radius.circular(isUser ? r : 0),
      topRight: Radius.circular(isUser ? 0 : r),
      bottomLeft: Radius.circular(r),
      bottomRight: Radius.circular(r),
    );
  }

  static ShapeDecoration messageBubbleDecoration(
    BuildContext context, {
    required bool isUser,
    required bool transparent,
    required bool hasBackground,
    required double bubbleOpacity,
    required bool highlighted,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final radius = context.appChatBubbleCornerRadius;

    final Color fill;
    if (transparent && hasBackground) {
      fill = isUser
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHigh.withValues(alpha: 0.55);
    } else if (isUser) {
      fill = hasBackground
          ? scheme.primaryContainer.withValues(alpha: bubbleOpacity)
          : scheme.primaryContainer;
    } else {
      fill = hasBackground
          ? scheme.surfaceContainerHigh.withValues(alpha: bubbleOpacity)
          : scheme.surfaceContainerHigh;
    }

    return ShapeDecoration(
      color: fill,
      shape: ContinuousRectangleBorder(
        borderRadius: bubbleBorderRadius(isUser: isUser, radius: radius),
        side: highlighted
            ? BorderSide(color: scheme.tertiary, width: 3)
            : BorderSide.none,
      ),
    );
  }

  static Color bubbleTextColor(ColorScheme scheme, {required bool isUser}) =>
      isUser ? scheme.onPrimaryContainer : scheme.onSurface;

  /// Quoted speech (`"..."`) inside a bubble — distinct from narration.
  static Color dialogueTextColor(ColorScheme scheme, {required bool isUser}) {
    if (isUser) {
      return Color.lerp(scheme.onPrimaryContainer, scheme.tertiary, 0.55)!;
    }
    return scheme.tertiary;
  }

  /// Shared chat body size for bubbles and the composer input.
  ///
  /// Uses [TextTheme.bodyMedium] so theme font-size prefs stay in sync.
  static double messageFontSize(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;

  /// Shared chat body text style for the composer field.
  static TextStyle messageInputStyle(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    return (base ?? const TextStyle(fontSize: 14, height: 1.4)).copyWith(
      color: color ?? theme.colorScheme.onSurface,
      fontSize: messageFontSize(context),
      height: base?.height ?? 1.4,
    );
  }
}
