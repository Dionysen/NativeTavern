import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

/// Opens a location owned by the stateful shell (a bottom/rail tab).
///
/// In three-pane desktop mode this uses [GoRouter.go] so the shell switches to
/// the owning tab and shows that tab's master-detail. In single-pane / stack
/// layouts this uses [GoRouter.push] so back-stack behavior stays unchanged.
///
/// Also keys off window width so root overlays (e.g. groups) still switch tabs
/// when the desktop three-pane shell is active underneath.
extension ShellTabNavigation on BuildContext {
  bool get _shouldSwitchShellTab =>
      ThreePaneScope.isActive(this) || DesktopLayout.useThreePaneOf(this);

  void openShell(String location, {Object? extra}) {
    if (_shouldSwitchShellTab) {
      go(location, extra: extra);
    } else {
      push(location, extra: extra);
    }
  }
}
