import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

import '../../theme/native_tavern_theme.dart';

/// Icon + title divider used between major settings categories.
class SettingsCategoryHeader extends StatelessWidget {
  const SettingsCategoryHeader({
    super.key,
    required this.icon,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 10),
  });

  final IconData icon;
  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared spacing for settings-style control rows.
abstract final class SettingsTileMetrics {
  static const double iconSize = 22;
  static const double iconGap = 14;
  static const double horizontalPadding = 16;
  static const double verticalPadding = 10;
  static const double minHeight = 52;
}

/// Nested block shown under an expandable settings row.
///
/// Inset + quieter surface so expanded content reads as a child of the
/// parent grouped panel, not another sibling card.
class SettingsExpandedBlock extends StatelessWidget {
  const SettingsExpandedBlock({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.appCornerRadius);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Card chrome shared by [SettingsSection] and grouped reorderable lists.
class SettingsGroupedPanel extends StatelessWidget {
  const SettingsGroupedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  static BoxDecoration decoration(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(context.appCornerRadius),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: dark ? 0.10 : 0.12),
          blurRadius: 12,
          offset: const Offset(0, 3),
          spreadRadius: -1,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.appCornerRadius);
    return DecoratedBox(
      decoration: decoration(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Grouped block of settings tiles with an optional icon + title header.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.children,
    this.title,
    this.icon,
    this.footer,
    this.margin = const EdgeInsets.only(bottom: 20),
  });

  final String? title;
  final IconData? icon;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            if (icon != null)
              SettingsCategoryHeader(
                icon: icon!,
                title: title!,
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  title!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
          SettingsGroupedPanel(
            child: Column(children: children),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                footer!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings-style control row used by settings pages and reorderable managers.
class SettingsControlTile extends StatelessWidget {
  const SettingsControlTile({
    super.key,
    this.icon,
    this.leading,
    this.dragIndex,
    required this.title,
    this.subtitle,
    this.titleExtras,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.enabled = true,
    this.iconColor,
    this.maxSubtitleLines = 3,
  });

  final IconData? icon;
  final Widget? leading;
  final int? dragIndex;
  final String title;
  final String? subtitle;
  final List<Widget>? titleExtras;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool enabled;
  final Color? iconColor;
  final int maxSubtitleLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = enabled ? scheme.onSurfaceVariant : theme.disabledColor;
    final resolvedIconColor = iconColor ?? muted;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: enabled ? null : theme.disabledColor,
    );
    final subtitleStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.3,
      color: enabled
          ? scheme.onSurfaceVariant.withValues(alpha: 0.72)
          : theme.disabledColor,
    );

    Widget? leadingWidget = leading;
    if (leadingWidget == null && icon != null) {
      leadingWidget = Icon(
        icon,
        size: SettingsTileMetrics.iconSize,
        color: resolvedIconColor,
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SettingsTileMetrics.minHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SettingsTileMetrics.horizontalPadding,
                vertical: SettingsTileMetrics.verticalPadding,
              ),
              child: Row(
                children: [
                  if (dragIndex != null) ...[
                    ReorderableDragStartListener(
                      index: dragIndex!,
                      child: Icon(
                        Icons.drag_handle,
                        size: SettingsTileMetrics.iconSize,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (leadingWidget != null) ...[
                    leadingWidget,
                    const SizedBox(width: SettingsTileMetrics.iconGap),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: maxSubtitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (titleExtras != null && titleExtras!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: titleExtras!,
                    ),
                  ],
                  if (trailing != null) ...[
                    SizedBox(
                      width: titleExtras != null && titleExtras!.isNotEmpty
                          ? 2
                          : 8,
                    ),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: SettingsTileMetrics.horizontalPadding,
            endIndent: SettingsTileMetrics.horizontalPadding,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

/// Horizontal settings row: leading icon, title, optional trailing.
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.enabled = true,
    this.maxSubtitleLines = 3,
  });

  static const double iconSize = SettingsTileMetrics.iconSize;

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool enabled;
  final int maxSubtitleLines;

  @override
  Widget build(BuildContext context) {
    return SettingsControlTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      showDivider: showDivider,
      enabled: enabled,
      maxSubtitleLines: maxSubtitleLines,
    );
  }
}

/// Settings row with a Material [Switch].
/// Compact [Switch] that follows theme [SwitchTheme] (accent track, white thumb).
class ThemedSwitch extends StatelessWidget {
  const ThemedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: ChromeControls.settingsSwitchScale,
      alignment: Alignment.centerRight,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: ThemedSwitch(value: value, onChanged: onChanged),
    );
  }
}

class SettingsChoice<T> {
  const SettingsChoice({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

/// Value disclosure tile that opens a modal choice list.
class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.choices,
    required this.valueLabel,
    required this.onSelected,
    this.subtitle,
    this.showDivider = true,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final T selected;
  final List<SettingsChoice<T>> choices;
  final String valueLabel;
  final ValueChanged<T> onSelected;
  final bool showDivider;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final next = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.appCornerRadius + 4),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final choice in choices)
                ListTile(
                  title: Text(choice.label),
                  subtitle: choice.subtitle != null
                      ? Text(choice.subtitle!)
                      : null,
                  trailing: choice.value == selected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(choice.value),
                ),
            ],
          ),
        );
      },
    );
    if (next != null) onSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = enabled ? scheme.onSurfaceVariant : Theme.of(context).disabledColor;
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      enabled: enabled,
      onTap: enabled ? () => _pick(context) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: muted, size: 20),
        ],
      ),
    );
  }
}

/// Settings row showing a value string with a chevron (navigational / disclosure).
class SettingsValueTile extends StatelessWidget {
  const SettingsValueTile({
    super.key,
    required this.icon,
    required this.title,
    required this.valueText,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String valueText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (valueText.isNotEmpty) ...[
            Flexible(
              child: Text(
                valueText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: enabled
                          ? scheme.onSurfaceVariant
                          : Theme.of(context).disabledColor,
                    ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            Icons.chevron_right,
            color: enabled
                ? scheme.onSurfaceVariant
                : Theme.of(context).disabledColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Standard padded [ListView] body used by Zephyr-style settings pages.
class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: padding,
      children: children,
    );
  }
}

/// Inline slider row for settings sections (kept inside [SettingsSection]).
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.subtitle,
    this.divisions,
    this.enabled = true,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final int? divisions;
  final bool enabled;
  final bool showDivider;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.disabledColor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Icon(icon, size: SettingsListTile.iconSize, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: enabled ? null : theme.disabledColor,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          height: 1.3,
                          color: enabled
                              ? theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.72)
                              : theme.disabledColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                valueLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

/// Compact number tile that opens a slider dialog.
class SettingsNumberTile extends StatelessWidget {
  const SettingsNumberTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.onChanged,
    this.subtitle,
    this.suffix = '',
    this.divisions,
    this.decimalPlaces,
    this.showDivider = true,
    this.defaultLabelBuilder,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final String suffix;
  final int? divisions;
  /// When null, uses 1 decimal if [divisions] is null, otherwise 0.
  final int? decimalPlaces;
  final ValueChanged<double> onChanged;
  final bool showDivider;
  final String Function(String formattedDefault)? defaultLabelBuilder;

  String _format(double v) {
    final decimals = decimalPlaces ?? (divisions == null ? 1 : 0);
    return '${v.toStringAsFixed(decimals)}$suffix';
  }

  Future<void> _pick(BuildContext context) async {
    var current = value.clamp(min, max);
    final next = await showDialog<double>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final step = divisions == null || divisions! <= 0
                ? (max - min) / 20
                : (max - min) / divisions!;
            void nudge(double delta) {
              final raw = (current + delta).clamp(min, max);
              final snapped = divisions == null
                  ? raw
                  : (min + (((raw - min) / step).round() * step))
                      .clamp(min, max);
              setState(() => current = snapped.toDouble());
            }

            final defaultFormatted = _format(defaultValue);
            final defaultLabel = defaultLabelBuilder?.call(defaultFormatted) ??
                'Default $defaultFormatted';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: context.appBorderRadius,
              ),
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _format(current),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    defaultLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChromeIconButton(
                        onPressed: current <= min ? null : () => nudge(-step),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Expanded(
                        child: Slider(
                          value: current,
                          min: min,
                          max: max,
                          divisions: divisions,
                          onChanged: (v) => setState(() => current = v),
                        ),
                      ),
                      ChromeIconButton(
                        onPressed: current >= max ? null : () => nudge(step),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                ChromeIconButton(
                  tooltip: defaultLabel,
                  onPressed: () => setState(() => current = defaultValue),
                  icon: const Icon(Icons.restart_alt),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(current),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
    if (next != null) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      onTap: () => _pick(context),
      trailing: Text(
        _format(value),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
