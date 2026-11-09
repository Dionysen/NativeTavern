import 'package:flutter/material.dart';
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
/// Below the three-pane breakpoint this returns [detail] or [primary] only —
/// same stack feel as before. At ≥960 it shows both with dividers and surface
/// steps.
///
/// [detail] must be null when the branch is on its hub route. [ShellRoute]'s
/// `child` is a navigator subtree, not [MasterDetailPlaceholder], so emptiness
/// is decided by path at the call site.
class MasterDetailBranch extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final threePane = DesktopLayout.useThreePane(constraints.maxWidth);
        final hasDetail = detail != null;

        if (!threePane) {
          return ThreePaneScope(
            active: false,
            child: hasDetail ? detail! : primary,
          );
        }

        final scheme = Theme.of(context).colorScheme;
        final dividerColor = Theme.of(context).dividerColor.withValues(
              alpha: 0.5,
            );

        return ThreePaneScope(
          active: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: scheme.surfaceContainerLow,
                child: SizedBox(
                  width: DesktopLayout.primaryPaneWidth,
                  child: primary,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: dividerColor,
              ),
              Expanded(
                child: ColoredBox(
                  color: scheme.surface,
                  child: hasDetail
                      ? detail!
                      : EmptySecondaryPane(message: emptyLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
