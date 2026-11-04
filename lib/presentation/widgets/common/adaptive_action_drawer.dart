import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// One row in [showAdaptiveActionDrawer] / [AdaptiveActionMenuButton].
class AdaptiveActionDrawerItem<T> {
  const AdaptiveActionDrawerItem({
    required this.value,
    required this.title,
    this.leading,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
    this.showDividerAbove = false,
  });

  final T value;
  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final bool enabled;
  final bool destructive;

  /// When true, a section divider is drawn above this item.
  final bool showDividerAbove;
}

/// Shared bottom-sheet action menu used across AppBar overflow and list rows.
///
/// Prefer this over [PopupMenuButton] / [AdaptivePopupMenuButton] for action
/// lists (load / save / edit / delete). Keep popup menus only for compact
/// value pickers (sort, enum, format).
Future<T?> showAdaptiveActionDrawer<T>({
  required BuildContext context,
  String? title,
  required List<AdaptiveActionDrawerItem<T>> actions,
}) {
  assert(actions.isNotEmpty, 'Action drawer requires at least one action.');

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.appCornerRadius + 4),
      ),
    ),
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      final titleStyle = Theme.of(sheetContext).textTheme.titleMedium;
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null && title.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: actions.length,
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    final iconColor = !action.enabled
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : action.destructive
                            ? scheme.error
                            : scheme.onSurfaceVariant;
                    final titleColor = !action.enabled
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : action.destructive
                            ? scheme.error
                            : null;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (action.showDividerAbove) const Divider(height: 1),
                        ListTile(
                          enabled: action.enabled,
                          leading: action.leading == null
                              ? null
                              : IconTheme.merge(
                                  data: IconThemeData(
                                    size: ChromeControls.menuIconSize,
                                    color: iconColor,
                                  ),
                                  child: action.leading!,
                                ),
                          title: DefaultTextStyle.merge(
                            style: TextStyle(color: titleColor),
                            child: action.title,
                          ),
                          subtitle: action.subtitle,
                          onTap: action.enabled
                              ? () =>
                                  Navigator.pop(sheetContext, action.value)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Icon / child trigger that opens [showAdaptiveActionDrawer].
///
/// Drop-in replacement for action-oriented [AdaptivePopupMenuButton] usages.
class AdaptiveActionMenuButton<T> extends StatelessWidget {
  const AdaptiveActionMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.child,
    this.tooltip,
    this.title,
    this.padding = const EdgeInsets.all(8),
    this.iconSize,
    this.enabled = true,
    this.visualDensity,
    this.constraints,
    this.style,
  });

  final List<AdaptiveActionDrawerItem<T>> Function(BuildContext context)
      itemBuilder;
  final ValueChanged<T> onSelected;
  final Widget? icon;
  final Widget? child;
  final String? tooltip;
  final String? title;
  final EdgeInsetsGeometry padding;
  final double? iconSize;
  final bool enabled;
  final VisualDensity? visualDensity;
  final BoxConstraints? constraints;
  final ButtonStyle? style;

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final selected = await showAdaptiveActionDrawer<T>(
      context: context,
      title: title,
      actions: itemBuilder(context),
    );
    if (selected == null || !context.mounted) return;
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = icon ?? const Icon(Icons.more_vert);
    if (child != null) {
      return Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: enabled ? () => _open(context) : null,
          customBorder: context.appShape.iconButtonShape,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    return IconButton(
      icon: resolvedIcon,
      tooltip: tooltip,
      padding: padding,
      iconSize: iconSize,
      visualDensity: visualDensity,
      constraints: constraints,
      style: style,
      onPressed: enabled ? () => _open(context) : null,
    );
  }
}
