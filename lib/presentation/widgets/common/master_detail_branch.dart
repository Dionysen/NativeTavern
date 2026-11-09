import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// Primary pane width is shared via [primaryPaneWidthProvider] so every tab
/// keeps the same divider position.
///
/// [detail] must be null when the branch is on its hub route. [ShellRoute]'s
/// `child` is a navigator subtree, not [MasterDetailPlaceholder], so emptiness
/// is decided by path at the call site.
class MasterDetailBranch extends ConsumerStatefulWidget {
  const MasterDetailBranch({
    super.key,
    required this.primary,
    required this.detail,
    required this.emptyLabel,
  });

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
                  // Anchor to drag-start geometry so multiple pointer updates
                  // between frames stay in sync with the pointer.
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
