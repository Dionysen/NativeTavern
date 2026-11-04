import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// Compact value-picker popup anchored to its trigger.
///
/// Use this for sort / enum / format selection. For action lists (edit /
/// delete / import / export), use [showAdaptiveActionDrawer] /
/// [AdaptiveActionMenuButton] instead.
///
/// Flutter 3.44.9 or newer is required because older releases could interpret
/// an iPadOS top-bar tap twice and immediately dismiss the opened menu.
class AdaptivePopupMenuButton<T> extends StatelessWidget {
  const AdaptivePopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.child,
    this.tooltip,
    this.padding = const EdgeInsets.all(8),
    this.iconSize,
    this.enabled = true,
    this.initialValue,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final Widget? icon;
  final Widget? child;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final double? iconSize;
  final bool enabled;
  final T? initialValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        iconTheme: theme.iconTheme.copyWith(
          size: ChromeControls.menuIconSize,
        ),
        listTileTheme: theme.listTileTheme.copyWith(
          dense: true,
          visualDensity: ChromeControls.menuVisualDensity,
          minVerticalPadding: 0,
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: ChromeControls.menuTitleGap,
          minLeadingWidth: ChromeControls.menuLeadingWidth,
        ),
      ),
      child: PopupMenuButton<T>(
        itemBuilder: (context) =>
            itemBuilder(context).map(_compactEntry).toList(growable: false),
        onSelected: onSelected,
        icon: icon,
        tooltip: tooltip,
        padding: padding,
        iconSize: iconSize,
        enabled: enabled,
        initialValue: initialValue,
        style: IconButton.styleFrom(
          shape: ChromeControls.iconButtonShapeFor(),
        ),
        child: child,
      ),
    );
  }

  PopupMenuEntry<T> _compactEntry(PopupMenuEntry<T> entry) {
    if (entry is! PopupMenuItem<T>) return entry;

    final useCompactHeight = entry.height == kMinInteractiveDimension;
    return PopupMenuItem<T>(
      key: entry.key,
      value: entry.value,
      onTap: entry.onTap,
      enabled: entry.enabled,
      height: useCompactHeight
          ? ChromeControls.menuItemHeight
          : entry.height,
      padding: entry.padding ?? ChromeControls.menuItemPadding,
      textStyle: entry.textStyle,
      labelTextStyle: entry.labelTextStyle,
      mouseCursor: entry.mouseCursor,
      child: entry.child,
    );
  }
}

/// Compact list row used inside [PopupMenuItem] / [AdaptivePopupMenuButton].
///
/// Prefer this over a raw [ListTile] so overflow menus stay dense and aligned.
class PopupMenuListTile extends StatelessWidget {
  const PopupMenuListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleColor,
    this.iconColor,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: titleColor ?? theme.listTileTheme.textColor,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.listTileTheme.subtitleTextStyle?.color ??
          theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
      fontSize: 12,
      height: 1.15,
    );

    final textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(style: titleStyle, child: title),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          DefaultTextStyle.merge(style: subtitleStyle, child: subtitle!),
        ],
      ],
    );

    return IconTheme.merge(
      data: IconThemeData(
        size: ChromeControls.menuIconSize,
        color: iconColor ?? theme.listTileTheme.iconColor,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            SizedBox(
              width: ChromeControls.menuLeadingWidth,
              child: Center(child: leading),
            ),
            SizedBox(width: ChromeControls.menuTitleGap),
          ],
          Expanded(child: textColumn),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Convenience builder for a compact [PopupMenuItem] with icon + title.
PopupMenuItem<T> adaptivePopupMenuItem<T>({
  Key? key,
  required T value,
  required Widget title,
  Widget? subtitle,
  Widget? leading,
  Widget? trailing,
  bool enabled = true,
  Color? titleColor,
  Color? iconColor,
}) {
  return PopupMenuItem<T>(
    key: key,
    value: value,
    enabled: enabled,
    height: ChromeControls.menuItemHeight,
    padding: ChromeControls.menuItemPadding,
    child: PopupMenuListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      titleColor: titleColor,
      iconColor: iconColor,
    ),
  );
}
