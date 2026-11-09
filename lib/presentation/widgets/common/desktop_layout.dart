import 'package:flutter/widgets.dart';

/// Shared breakpoints for desktop shell chrome.
///
/// - `&lt; [railBreakpoint]`: bottom navigation
/// - `[railBreakpoint]`–`[threePaneBreakpoint]`: rail + single content
/// - `≥ [threePaneBreakpoint]`: rail + primary + secondary
abstract final class DesktopLayout {
  static const double railBreakpoint = 600;
  static const double threePaneBreakpoint = 960;
  static const double primaryPaneWidth = 320;

  static bool useRail(double width) => width >= railBreakpoint;

  static bool useThreePane(double width) => width >= threePaneBreakpoint;

  static bool useThreePaneOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return useThreePane(width);
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
