import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';

/// Density for [ChromeIconButton].
enum ChromeIconButtonDensity {
  /// Theme AppBar / toolbar size (40×40, 22px icon).
  standard,

  /// Dense list / inline chrome (28×28, 20px icon).
  compact,
}

/// Shared circular icon-only button used across NativeTavern chrome.
///
/// Prefer this over raw [IconButton] so size, shape, and density stay
/// consistent. Labeled buttons (Filled / Outlined / Text with text) stay on
/// their own themes.
class ChromeIconButton extends StatelessWidget {
  const ChromeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.density = ChromeIconButtonDensity.standard,
    this.color,
    this.disabledColor,
    this.iconSize,
    this.isSelected,
    this.selectedIcon,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.enableFeedback,
  }) : _variant = _ChromeIconButtonVariant.standard;

  const ChromeIconButton.filled({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.density = ChromeIconButtonDensity.standard,
    this.color,
    this.disabledColor,
    this.iconSize,
    this.isSelected,
    this.selectedIcon,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.enableFeedback,
  }) : _variant = _ChromeIconButtonVariant.filled;

  const ChromeIconButton.filledTonal({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.density = ChromeIconButtonDensity.standard,
    this.color,
    this.disabledColor,
    this.iconSize,
    this.isSelected,
    this.selectedIcon,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.enableFeedback,
  }) : _variant = _ChromeIconButtonVariant.filledTonal;

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final ChromeIconButtonDensity density;
  final Color? color;
  final Color? disabledColor;
  final double? iconSize;
  final bool? isSelected;
  final Widget? selectedIcon;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? enableFeedback;
  final _ChromeIconButtonVariant _variant;

  bool get _isCompact => density == ChromeIconButtonDensity.compact;

  double get _resolvedIconSize {
    if (iconSize != null) return iconSize!;
    return _isCompact
        ? ChromeControls.menuIconSize
        : ChromeControls.mobileIconSize;
  }

  EdgeInsetsGeometry? get _resolvedPadding {
    if (!_isCompact) return null;
    return EdgeInsets.zero;
  }

  BoxConstraints? get _resolvedConstraints {
    if (!_isCompact) return null;
    return const BoxConstraints(
      minWidth: ChromeControls.buttonSize,
      minHeight: ChromeControls.buttonSize,
    );
  }

  ButtonStyle get _densityStyle {
    final shape = ChromeControls.iconButtonShapeFor();
    if (!_isCompact) {
      return IconButton.styleFrom(shape: shape);
    }
    return IconButton.styleFrom(
      shape: shape,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      minimumSize: const Size(
        ChromeControls.buttonSize,
        ChromeControls.buttonSize,
      ),
      fixedSize: const Size(
        ChromeControls.buttonSize,
        ChromeControls.buttonSize,
      ),
      iconSize: _resolvedIconSize,
    );
  }

  ButtonStyle get _mergedStyle {
    final base = _densityStyle;
    final override = style;
    if (override == null) return base;
    return base.merge(override);
  }

  @override
  Widget build(BuildContext context) {
    switch (_variant) {
      case _ChromeIconButtonVariant.filled:
        return IconButton.filled(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          color: color,
          disabledColor: disabledColor,
          iconSize: _resolvedIconSize,
          padding: _resolvedPadding,
          constraints: _resolvedConstraints,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          style: _mergedStyle,
          focusNode: focusNode,
          autofocus: autofocus,
          enableFeedback: enableFeedback,
        );
      case _ChromeIconButtonVariant.filledTonal:
        return IconButton.filledTonal(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          color: color,
          disabledColor: disabledColor,
          iconSize: _resolvedIconSize,
          padding: _resolvedPadding,
          constraints: _resolvedConstraints,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          style: _mergedStyle,
          focusNode: focusNode,
          autofocus: autofocus,
          enableFeedback: enableFeedback,
        );
      case _ChromeIconButtonVariant.standard:
        return IconButton(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          color: color,
          disabledColor: disabledColor,
          iconSize: iconSize ?? (_isCompact ? _resolvedIconSize : null),
          padding: _resolvedPadding,
          constraints: _resolvedConstraints,
          isSelected: isSelected,
          selectedIcon: selectedIcon,
          style: _mergedStyle,
          focusNode: focusNode,
          autofocus: autofocus,
          enableFeedback: enableFeedback,
          visualDensity: _isCompact ? VisualDensity.compact : null,
        );
    }
  }
}

enum _ChromeIconButtonVariant { standard, filled, filledTonal }
