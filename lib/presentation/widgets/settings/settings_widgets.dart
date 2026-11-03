import 'package:flutter/material.dart';

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
    final radius = context.appCornerRadius;
    final dark = theme.brightness == Brightness.dark;
    final fill = scheme.surfaceContainerHigh;
    final shadowColor = scheme.shadow.withValues(alpha: dark ? 0.10 : 0.12);

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
          DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: children),
                ),
              ),
            ),
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
  });

  static const double iconSize = 22;
  static const double _iconGap = 14;
  static const double _horizontalPadding = 16;

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor =
        enabled ? theme.colorScheme.onSurface : theme.disabledColor;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: enabled ? null : theme.disabledColor,
    );
    final subtitleStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.3,
      color: enabled
          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72)
          : theme.disabledColor,
    );

    return Column(
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(icon, size: iconSize, color: iconColor),
                  const SizedBox(width: _iconGap),
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
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
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
            indent: _horizontalPadding,
            endIndent: _horizontalPadding,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

/// Settings row with a Material [Switch].
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
      trailing: Transform.scale(
        scale: ChromeControls.settingsSwitchScale,
        alignment: Alignment.centerRight,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final T selected;
  final List<SettingsChoice<T>> choices;
  final String valueLabel;
  final ValueChanged<T> onSelected;
  final bool showDivider;

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
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      onTap: () => _pick(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valueLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
        ],
      ),
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
  final ValueChanged<double> onChanged;
  final bool showDivider;
  final String Function(String formattedDefault)? defaultLabelBuilder;

  String _format(double v) {
    final decimals = divisions == null ? 1 : 0;
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
                      IconButton(
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
                      IconButton(
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
                IconButton(
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
