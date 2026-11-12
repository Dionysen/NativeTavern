import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/widgets/common/app_viewport.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

/// Whether the shell is showing the side rail rather than bottom navigation.
///
/// Matches [AppShell]: a system vertical bar when the host provides one,
/// otherwise the width rail. Bottom navigation never takes this path.
bool usesSideNavigation(BuildContext context) {
  final layout = WindowLayoutScope.maybeOf(context);
  if (layout != null && layout.supportsVerticalBars) {
    return layout.verticalBarEdge != null;
  }
  return DesktopLayout.useRail(MediaQuery.sizeOf(context).width);
}

/// Opens a location owned by the stateful shell (a bottom/rail tab).
///
/// Side navigation uses [GoRouter.go] so the rail switches to the owning tab.
/// Bottom navigation keeps the previous stack: detail pages that used to cover
/// the shell are pushed on the root navigator, and the selected tab does not
/// change. Hub-to-hub jumps still [GoRouter.push] the shell location.
extension ShellTabNavigation on BuildContext {
  void openShell(String location, {Object? extra}) {
    if (usesSideNavigation(this)) {
      go(location, extra: extra);
      return;
    }
    if (AppRoutes.opensOnRootInBottomNav(location)) {
      push(AppRoutes.bottomStackLocation(location), extra: extra);
      return;
    }
    push(location, extra: extra);
  }
}

/// Moves a bottom-nav root overlay into the shell when the window grows wide
/// enough for the side rail (chat list | detail, etc.).
///
/// Without this, `/stack?to=/chat/...` keeps covering the shell until popped.
class BottomStackSideNavMigrator extends StatefulWidget {
  const BottomStackSideNavMigrator({
    super.key,
    required this.target,
    required this.child,
  });

  /// Shell-owned location originally opened via [AppRoutes.bottomStackLocation].
  final String target;
  final Widget child;

  @override
  State<BottomStackSideNavMigrator> createState() =>
      _BottomStackSideNavMigratorState();
}

class _BottomStackSideNavMigratorState
    extends State<BottomStackSideNavMigrator> {
  bool _migrateQueued = false;

  void _queueMigrateIfNeeded() {
    if (!usesSideNavigation(context) || _migrateQueued) return;
    _migrateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _migrateQueued = false;
      if (!mounted || !usesSideNavigation(context)) return;
      context.go(widget.target);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queueMigrateIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BottomStackSideNavMigrator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _queueMigrateIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Width changes update [MediaQuery] without always hitting
    // [didChangeDependencies]; re-check here so resize migrates live.
    _queueMigrateIfNeeded();
    return widget.child;
  }
}
