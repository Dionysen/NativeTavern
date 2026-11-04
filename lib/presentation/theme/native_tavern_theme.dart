import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../data/models/theme/theme_tokens.dart';
import '../../data/models/theme/ui_preferences.dart';

/// Shared chrome sizes for toolbar / settings controls.
abstract final class ChromeControls {
  static const double buttonSize = 28;
  static const double iconSize = 16;
  /// AppBar / toolbar IconButtons — same on every platform (Android reference).
  static const double mobileButtonSize = 40;
  static const double mobileIconSize = 22;
  /// Trailing inset so AppBar actions are not flush to the window edge.
  static const double appBarActionsEndPadding = 12;
  /// Horizontal gap inserted between AppBar action children.
  static const double appBarActionGap = 8;
  static const double defaultCornerRadius = 4;
  static const double fieldHeight = 36;
  static const double menuInsets = 4;
  static const double borderWidth = 1;
  static const double settingsSwitchScale = 0.82;
  static const double menuItemHeight = 36;

  static bool isCircularRadius(double radius) => radius >= buttonSize / 2;

  static OutlinedBorder iconButtonShapeFor(double radius) =>
      isCircularRadius(radius)
          ? const CircleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  static OutlinedBorder labeledButtonShapeFor(double radius) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isCircularRadius(radius) ? buttonSize / 2 : radius,
        ),
      );

  static OutlinedBorder menuShapeFor(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
}

/// User-owned chrome shape prefs exposed through [ThemeData.extensions].
@immutable
class AppShapeTheme extends ThemeExtension<AppShapeTheme> {
  const AppShapeTheme({
    required this.cornerRadius,
    this.barCornerRadius = 4,
    this.chatBubbleCornerRadius = 30,
    this.showBorders = false,
  });

  final double cornerRadius;
  final double barCornerRadius;
  final double chatBubbleCornerRadius;
  final bool showBorders;

  BorderRadius get borderRadius => BorderRadius.circular(cornerRadius);

  BorderRadius get barBorderRadius => BorderRadius.circular(barCornerRadius);

  BorderRadius get chatBubbleBorderRadius =>
      BorderRadius.circular(chatBubbleCornerRadius);

  OutlinedBorder get iconButtonShape =>
      ChromeControls.iconButtonShapeFor(cornerRadius);

  OutlinedBorder get labeledButtonShape =>
      ChromeControls.labeledButtonShapeFor(cornerRadius);

  OutlinedBorder get menuShape => ChromeControls.menuShapeFor(cornerRadius);

  BorderSide outlineSide(Color color) => showBorders
      ? BorderSide(color: color, width: ChromeControls.borderWidth)
      : BorderSide.none;

  @override
  AppShapeTheme copyWith({
    double? cornerRadius,
    double? barCornerRadius,
    double? chatBubbleCornerRadius,
    bool? showBorders,
  }) =>
      AppShapeTheme(
        cornerRadius: cornerRadius ?? this.cornerRadius,
        barCornerRadius: barCornerRadius ?? this.barCornerRadius,
        chatBubbleCornerRadius:
            chatBubbleCornerRadius ?? this.chatBubbleCornerRadius,
        showBorders: showBorders ?? this.showBorders,
      );

  @override
  AppShapeTheme lerp(ThemeExtension<AppShapeTheme>? other, double t) {
    if (other is! AppShapeTheme) return this;
    return AppShapeTheme(
      cornerRadius: lerpDouble(cornerRadius, other.cornerRadius, t)!,
      barCornerRadius: lerpDouble(barCornerRadius, other.barCornerRadius, t)!,
      chatBubbleCornerRadius:
          lerpDouble(chatBubbleCornerRadius, other.chatBubbleCornerRadius, t)!,
      showBorders: t < 0.5 ? showBorders : other.showBorders,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppShapeTheme get appShape =>
      Theme.of(this).extension<AppShapeTheme>() ??
      const AppShapeTheme(cornerRadius: ChromeControls.defaultCornerRadius);

  double get appCornerRadius => appShape.cornerRadius;

  BorderRadius get appBorderRadius => appShape.borderRadius;

  double get appBarCornerRadius => appShape.barCornerRadius;

  BorderRadius get appBarBorderRadius => appShape.barBorderRadius;

  double get appChatBubbleCornerRadius => appShape.chatBubbleCornerRadius;

  bool get appShowBorders => appShape.showBorders;

  BorderSide appOutlineSide([Color? color]) =>
      appShape.outlineSide(color ?? Theme.of(this).colorScheme.outline);
}

/// Inserts a fixed gap between AppBar action children so desktop and mobile
/// match (Material AppBar packs actions with zero spacing by default).
List<Widget> spacedAppBarActions(Iterable<Widget> actions) {
  final list = actions.toList(growable: false);
  if (list.length <= 1) return list;
  return [
    for (var i = 0; i < list.length; i++) ...[
      if (i > 0) const SizedBox(width: ChromeControls.appBarActionGap),
      list[i],
    ],
  ];
}

/// Builds Material theme from semantic tokens + chrome prefs.
ThemeData buildNativeTavernTheme(
  ThemeTokens tokens, {
  UiPreferences ui = UiPreferences.defaults,
}) {
  final editor = Color(tokens.editorSurface);
  final sidebar = Color(tokens.sidebarSurface);
  final control = Color(tokens.controlSurface);
  final border = Color(tokens.border);
  final divider = Color(tokens.divider);
  final primaryText = Color(tokens.primaryText);
  final mutedText = Color(tokens.mutedText);
  final accent = Color(tokens.accent);
  final cursor = Color(tokens.cursor);
  final brightness = editor.computeLuminance() < .5
      ? Brightness.dark
      : Brightness.light;
  final selected = Color.alphaBlend(accent.withValues(alpha: .20), sidebar);
  final focus = Color.alphaBlend(accent.withValues(alpha: .5), border);
  final scale = ui.scale;
  final radius = ui.cornerRadius.clamp(
    UiPreferences.minCornerRadius,
    UiPreferences.maxCornerRadius,
  );
  final barRadius = ui.barCornerRadius.clamp(
    UiPreferences.minBarCornerRadius,
    UiPreferences.maxBarCornerRadius,
  );
  final bubbleRadius = ui.chatBubbleCornerRadius.clamp(
    UiPreferences.minChatBubbleCornerRadius,
    UiPreferences.maxChatBubbleCornerRadius,
  );
  final shape = AppShapeTheme(
    cornerRadius: radius,
    barCornerRadius: barRadius,
    chatBubbleCornerRadius: bubbleRadius,
    showBorders: ui.showBorders,
  );
  final borderRadius = shape.borderRadius;
  final hairline = shape.outlineSide(border);
  final focusHairline = shape.outlineSide(focus);

  return ThemeData(
    useMaterial3: true,
    // Keep density identical on phone and desktop; adaptive compact on macOS
    // was shrinking chrome relative to Android.
    visualDensity: VisualDensity.standard,
    extensions: [shape],
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
        .copyWith(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: selected,
      onSecondaryContainer: primaryText,
      primaryContainer: Color.alphaBlend(
        accent.withValues(alpha: brightness == Brightness.dark ? .28 : .18),
        editor,
      ),
      onPrimaryContainer: primaryText,
      surface: editor,
      onSurface: primaryText,
      surfaceContainerLowest: sidebar,
      surfaceContainerLow: Color.alphaBlend(
        Colors.white.withValues(alpha: .02),
        sidebar,
      ),
      surfaceContainer: Color.alphaBlend(
        Colors.white.withValues(alpha: .03),
        editor,
      ),
      surfaceContainerHigh: control,
      surfaceContainerHighest: Color.alphaBlend(
        Colors.white.withValues(alpha: .04),
        control,
      ),
      onSurfaceVariant: mutedText,
      outline: border,
      outlineVariant: divider,
      error: brightness == Brightness.light
          ? const Color(0xFFB3261E)
          : const Color(0xFFFFB4AB),
      onError: brightness == Brightness.light ? Colors.white : null,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent;
        }
        return null;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return null;
      }),
    ),
    scaffoldBackgroundColor: editor,
    dividerTheme: DividerThemeData(
      color: divider,
      thickness: ChromeControls.borderWidth,
      space: 1,
    ),
    iconTheme: IconThemeData(
      color: primaryText.withValues(alpha: .76),
      size: ChromeControls.mobileIconSize,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: primaryText.withValues(alpha: .76),
        iconSize: ChromeControls.mobileIconSize,
        padding: const EdgeInsets.all(
          (ChromeControls.mobileButtonSize - ChromeControls.mobileIconSize) / 2,
        ),
        minimumSize: const Size(
          ChromeControls.mobileButtonSize,
          ChromeControls.mobileButtonSize,
        ),
        fixedSize: const Size(
          ChromeControls.mobileButtonSize,
          ChromeControls.mobileButtonSize,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: shape.iconButtonShape,
        overlayColor: accent.withValues(alpha: .12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryText,
        iconSize: ChromeControls.iconSize,
        shape: shape.labeledButtonShape.copyWith(side: hairline),
        side: hairline,
        visualDensity: VisualDensity.compact,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryText,
        iconSize: ChromeControls.iconSize,
        shape: shape.labeledButtonShape,
        visualDensity: VisualDensity.compact,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: primaryText,
        backgroundColor: accent.withValues(alpha: .24),
        iconSize: ChromeControls.iconSize,
        shape: shape.labeledButtonShape,
        visualDensity: VisualDensity.compact,
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        color: primaryText,
        fontSize: 20 * scale,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: primaryText,
        fontSize: 15 * scale,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        color: primaryText,
        fontSize: 16 * scale,
        height: 1.75,
      ),
      bodyMedium: TextStyle(
        color: primaryText,
        fontSize: 14 * scale,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        color: mutedText,
        fontSize: 13 * scale,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        color: primaryText.withValues(alpha: .70),
        fontSize: 12 * scale,
      ),
      labelSmall: TextStyle(
        color: mutedText.withValues(alpha: .82),
        fontSize: 11 * scale,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: editor,
      foregroundColor: primaryText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: shape.barBorderRadius),
      actionsPadding: const EdgeInsetsDirectional.only(
        end: ChromeControls.appBarActionsEndPadding,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: cursor,
      selectionColor: accent.withValues(alpha: .35),
      selectionHandleColor: cursor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: control,
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderSide: hairline,
        borderRadius: borderRadius,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: focusHairline,
        borderRadius: borderRadius,
      ),
      border: OutlineInputBorder(
        borderSide: hairline,
        borderRadius: borderRadius,
      ),
      hintStyle: TextStyle(color: mutedText.withValues(alpha: .78)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: control,
      shape: RoundedRectangleBorder(borderRadius: borderRadius, side: hairline),
    ),
    cardTheme: CardThemeData(
      color: control,
      shape: RoundedRectangleBorder(borderRadius: borderRadius, side: hairline),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: control, borderRadius: borderRadius),
      textStyle: TextStyle(color: primaryText),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: control,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: shape.menuShape.copyWith(side: hairline),
      menuPadding: const EdgeInsets.symmetric(
        vertical: ChromeControls.menuInsets,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: mutedText,
      textColor: primaryText,
    ),
    splashFactory: InkRipple.splashFactory,
    splashColor: accent.withValues(alpha: .14),
    highlightColor: accent.withValues(alpha: .08),
  );
}
