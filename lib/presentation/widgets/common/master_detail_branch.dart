import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/providers/desktop_layout_providers.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';
import 'package:native_tavern/presentation/widgets/common/empty_secondary_pane.dart';

/// Blank page for hub routes under a [ShellRoute]. Not used to detect emptiness
/// anymore — callers pass [detail] as null when the location is the hub.
class MasterDetailPlaceholder extends StatelessWidget {
  const MasterDetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Adaptive list | detail host for a shell branch.
///
/// When the host is narrower than both pane minimums this returns [detail] or
/// [primary] only — same stack feel as before. When both mins fit it shows
/// primary + resizable divider + secondary with surface steps.
///
/// Detail pages should wrap with [ShellHubBackEnabler] so single-pane AppBars
/// can imply a leading back to [hubPath] after a three-pane `go` + resize.
///
/// Primary pane width is shared via [primaryPaneWidthProvider] so every tab
/// keeps the same divider position.
///
/// [detail] must be null when the branch is on its hub route. [ShellRoute]'s
/// `child` is a navigator subtree, not [MasterDetailPlaceholder], so emptiness
/// is decided by path at the call site.
class MasterDetailBranch extends ConsumerStatefulWidget {
  const MasterDetailBranch({
    super.key,
    required this.hubPath,
    required this.primary,
    required this.detail,
    required this.emptyLabel,
  });

  /// Shell tab hub location (e.g. `/settings`) used for synthetic back.
  final String hubPath;

  final Widget primary;

  /// Matched shell child when a detail route is active; null on the hub.
  final Widget? detail;
  final String emptyLabel;

  @override
  ConsumerState<MasterDetailBranch> createState() => _MasterDetailBranchState();
}

class _MasterDetailBranchState extends ConsumerState<MasterDetailBranch> {
  double? _dragStartWidth;
  double? _dragStartGlobalX;

  @override
  Widget build(BuildContext context) {
    final sharedPrimaryWidth = ref.watch(primaryPaneWidthProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final threePane = DesktopLayout.useThreePane(contentWidth);
        final hasDetail = widget.detail != null;

        if (!threePane) {
          return ThreePaneScope(
            active: false,
            child: hasDetail ? widget.detail! : widget.primary,
          );
        }

        final scheme = Theme.of(context).colorScheme;
        final dividerColor = Theme.of(context).dividerColor.withValues(
              alpha: 0.5,
            );
        final primaryWidth = DesktopLayout.clampPrimaryPaneWidth(
          desired: sharedPrimaryWidth,
          contentWidth: contentWidth,
        );

        return ThreePaneScope(
          active: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: scheme.surfaceContainerLow,
                child: SizedBox(
                  width: primaryWidth,
                  child: widget.primary,
                ),
              ),
              _PaneResizeHandle(
                key: const ValueKey('pane-resize-handle'),
                color: dividerColor,
                onDragStart: (globalX) {
                  _dragStartGlobalX = globalX;
                  _dragStartWidth = primaryWidth;
                },
                onDragUpdate: (globalX) {
                  final startX = _dragStartGlobalX;
                  final startWidth = _dragStartWidth;
                  if (startX == null || startWidth == null) return;
                  final next = DesktopLayout.clampPrimaryPaneWidth(
                    desired: startWidth + (globalX - startX),
                    contentWidth: contentWidth,
                  );
                  ref.read(primaryPaneWidthProvider.notifier).state = next;
                },
              ),
              Expanded(
                child: ColoredBox(
                  color: scheme.surface,
                  child: hasDetail
                      ? widget.detail!
                      : EmptySecondaryPane(message: widget.emptyLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Installs a [LocalHistoryEntry] on the page route in single-pane mode so
/// AppBar can imply a leading back (with correct title inset) when GoRouter
/// used `go` and cannot pop — e.g. after resizing from three-pane.
///
/// No-ops while [ThreePaneScope] is active (list pane already visible).
class ShellHubBackEnabler extends StatefulWidget {
  const ShellHubBackEnabler({
    super.key,
    required this.hubPath,
    required this.child,
  });

  final String hubPath;
  final Widget child;

  @override
  State<ShellHubBackEnabler> createState() => _ShellHubBackEnablerState();
}

class _ShellHubBackEnablerState extends State<ShellHubBackEnabler> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ShellHubBackEnabler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hubPath != widget.hubPath) {
      _clearEntry();
      _sync();
    }
  }

  @override
  void dispose() {
    _clearEntry();
    super.dispose();
  }

  void _clearEntry() {
    final entry = _entry;
    final route = _route;
    _entry = null;
    _route = null;
    if (entry != null && route != null && route.isActive) {
      route.removeLocalHistoryEntry(entry);
    }
  }

  void _sync() {
    final route = ModalRoute.of(context);
    final wantsSynthetic = !ThreePaneScope.isActive(context) &&
        route != null &&
        route.isFirst;

    if (!wantsSynthetic) {
      _clearEntry();
      return;
    }

    if (_entry != null && identical(_route, route)) {
      return;
    }

    _clearEntry();
    _route = route;
    _entry = LocalHistoryEntry(
      onRemove: () {
        _entry = null;
        if (!context.mounted) return;
        context.go(widget.hubPath);
      },
    );
    route!.addLocalHistoryEntry(_entry!);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shell detail [NoTransitionPage] with [ShellHubBackEnabler] for AppBar back.
NoTransitionPage<void> shellDetailPage({
  required GoRouterState state,
  required String hubPath,
  required Widget child,
}) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: ShellHubBackEnabler(
      hubPath: hubPath,
      child: child,
    ),
  );
}

class _PaneResizeHandle extends StatelessWidget {
  const _PaneResizeHandle({
    super.key,
    required this.color,
    required this.onDragStart,
    required this.onDragUpdate,
  });

  final Color color;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) =>
            onDragStart(details.globalPosition.dx),
        onHorizontalDragUpdate: (details) =>
            onDragUpdate(details.globalPosition.dx),
        child: SizedBox(
          width: DesktopLayout.paneDividerWidth,
          child: Center(
            child: Container(
              width: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
