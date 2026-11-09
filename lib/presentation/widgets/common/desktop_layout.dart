import 'package:flutter/widgets.dart';

/// Shared breakpoints for desktop shell chrome.
///
/// - `&lt; [railBreakpoint]`: bottom navigation
/// - `[railBreakpoint]+` with content narrower than both pane mins: rail +
///   single content stack
/// - content wide enough for [primaryPaneMinWidth] + [secondaryPaneMinWidth]:
///   rail + primary + secondary
abstract final class DesktopLayout {
  static const double railBreakpoint = 600;

  /// Compact width-based nav rail (icon + label). Shared-bar hosts keep their
  /// own [WindowLayoutScope.barWidth].
  static const double railWidth = 72;

  /// Hairline between rail and content when three-pane chrome is on.
  static const double railDividerWidth = 1;

  static const double primaryPaneMinWidth = 280;
  static const double secondaryPaneMinWidth = 360;
  static const double primaryPaneDefaultWidth = 400;

  /// Draggable hit target between primary and secondary.
  static const double paneDividerWidth = 6;

  /// Minimum width of the master-detail host (body after rail) for side-by-side.
  static double get threePaneContentMinWidth =>
      primaryPaneMinWidth + secondaryPaneMinWidth + paneDividerWidth;

  /// Window width that can host rail + both panes (approx; prefer content check).
  static double get threePaneBreakpoint =>
      railWidth + railDividerWidth + threePaneContentMinWidth;

  static bool useRail(double width) => width >= railBreakpoint;

  /// [contentWidth] is the master-detail host width (window minus rail chrome).
  static bool useThreePane(double contentWidth) =>
      contentWidth >= threePaneContentMinWidth;

  static bool useThreePaneOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return useThreePane(width - railWidth - railDividerWidth);
  }

  static double clampPrimaryPaneWidth({
    required double desired,
    required double contentWidth,
  }) {
    final maxPrimary =
        contentWidth - secondaryPaneMinWidth - paneDividerWidth;
    if (maxPrimary < primaryPaneMinWidth) {
      return primaryPaneMinWidth;
    }
    return desired.clamp(primaryPaneMinWidth, maxPrimary);
  }
}

/// Marks that the current subtree is shown inside the wide three-pane shell.
class ThreePaneScope extends InheritedWidget {
  const ThreePaneScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool isActive(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThreePaneScope>();
    return scope?.active ?? false;
  }

  @override
  bool updateShouldNotify(ThreePaneScope oldWidget) =>
      active != oldWidget.active;
}
