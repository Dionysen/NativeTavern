import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

import '../../../data/models/theme/app_theme_mode.dart';
import '../../../data/models/theme/theme_color_pack.dart';
import '../../../data/models/theme/theme_tokens.dart';
import '../../providers/theme_providers.dart';
import '../../theme/native_tavern_theme.dart';
import '../../widgets/common/adaptive_action_drawer.dart';
import '../../widgets/settings/settings_widgets.dart';
import '../../widgets/settings/theme_color_picker.dart';

/// Theme colors and layout controls for the appearance settings page.
class ThemeSettingsPanels extends ConsumerStatefulWidget {
  const ThemeSettingsPanels({super.key});

  @override
  ConsumerState<ThemeSettingsPanels> createState() =>
      _ThemeSettingsPanelsState();
}

class _ThemeSettingsPanelsState extends ConsumerState<ThemeSettingsPanels> {
  var _customColorsExpanded = false;
  var _presetsExpanded = false;

  ThemeAppearanceNotifier get _notifier =>
      ref.read(themeProvider.notifier);

  Future<void> _pickTokenColor(ThemeToken token) async {
    final l10n = AppLocalizations.of(context);
    final current = Color(ref.read(themeProvider).tokens.valueOf(token));
    final next = await showThemeColorPicker(
      context,
      initialColor: current,
      title: _tokenLabel(l10n, token),
      cancelLabel: l10n.cancel,
      doneLabel: l10n.done,
    );
    if (next == null || !mounted) return;
    _notifier.updateToken(token, next.toARGB32());
  }

  Future<void> _saveAsThemeColor() async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final name = await _promptThemeName(
      title: l10n.saveThemeColorTitle,
      initialName: l10n.themePackNameDefault(notifier.nextDefaultThemeNumber()),
    );
    if (name == null || !mounted) return;
    notifier.saveCurrentAsTheme(name);
  }

  Future<String?> _promptThemeName({
    required String title,
    required String initialName,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initialName);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.saveThemeColorNameLabel),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isEmpty) return;
              Navigator.of(context).pop(trimmed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) return;
                Navigator.of(context).pop(trimmed);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _showCustomPackMenu(ThemeColorPack pack) async {
    if (pack.isBuiltIn) return;
    final l10n = AppLocalizations.of(context);
    final action = await showAdaptiveActionDrawer<_PackMenuAction>(
      context: context,
      title: pack.name,
      actions: [
        AdaptiveActionDrawerItem(
          value: _PackMenuAction.rename,
          leading: const Icon(Icons.drive_file_rename_outline),
          title: Text(l10n.rename),
        ),
        AdaptiveActionDrawerItem(
          value: _PackMenuAction.copy,
          leading: const Icon(Icons.copy_outlined),
          title: Text(l10n.copy),
        ),
        AdaptiveActionDrawerItem(
          value: _PackMenuAction.delete,
          leading: const Icon(Icons.delete_outline),
          title: Text(l10n.delete),
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    final notifier = _notifier;
    switch (action) {
      case _PackMenuAction.rename:
        final name = await _promptThemeName(
          title: l10n.themePackRenameTitle,
          initialName: pack.name,
        );
        if (name == null || !mounted) return;
        notifier.renameCustomPack(pack.id, name);
      case _PackMenuAction.copy:
        notifier.copyCustomPack(pack.id, l10n.themePackCopyName(pack.name));
      case _PackMenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.themePackDeleteTitle),
            content: Text(l10n.themePackDeleteBody(pack.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        notifier.deleteCustomPack(pack.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeState = ref.watch(themeProvider);
    final packs = themeState.colorPacks;
    final activePack = themeState.activePack;
    final activeMatches =
        activePack != null && activePack.tokens == themeState.tokens;
    final currentThemeLabel = activeMatches
        ? l10n.themeCurrentPreset(_packTitle(l10n, activePack))
        : l10n.themeCurrentCustom;

    return SettingsSection(
      icon: Icons.palette_outlined,
      title: l10n.themeColorsSectionTitle,
      children: [
              SettingsChoiceTile<AppThemeMode>(
                icon: Icons.brightness_6_outlined,
                title: l10n.themeModeTitle,
                subtitle: l10n.themeModeSubtitle,
                selected: themeState.themeMode,
                choices: [
                  SettingsChoice(
                    value: AppThemeMode.system,
                    label: l10n.themeModeSystem,
                  ),
                  SettingsChoice(
                    value: AppThemeMode.light,
                    label: l10n.themeModeLight,
                  ),
                  SettingsChoice(
                    value: AppThemeMode.dark,
                    label: l10n.themeModeDark,
                  ),
                ],
                valueLabel: _themeModeLabel(l10n, themeState.themeMode),
                onSelected: _notifier.setThemeMode,
              ),
              SettingsListTile(
                icon: Icons.palette_outlined,
                title: l10n.themePresetsSectionTitle,
                subtitle: currentThemeLabel,
                showDivider: true,
                trailing: Icon(
                  _presetsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () =>
                    setState(() => _presetsExpanded = !_presetsExpanded),
              ),
              if (_presetsExpanded)
                _ExpandedSettingsBlock(
                  children: [
                    for (var i = 0; i < packs.length; i++)
                      SettingsListTile(
                        icon: Icons.style_outlined,
                        title: _packTitle(l10n, packs[i]),
                        showDivider: i != packs.length - 1,
                        trailing: _packTrailing(
                          context,
                          l10n,
                          packId: packs[i].id,
                          lightPackId: themeState.lightPackId,
                          darkPackId: themeState.darkPackId,
                          isActive: activeMatches &&
                              packs[i].id == themeState.activePackId,
                        ),
                        onTap: () => _notifier.applyPack(packs[i].id),
                        onLongPress: packs[i].isBuiltIn
                            ? null
                            : () => _showCustomPackMenu(packs[i]),
                      ),
                  ],
                ),
              SettingsListTile(
                icon: Icons.color_lens_outlined,
                title: l10n.customColorsTitle,
                subtitle: l10n.customColorsSubtitle,
                showDivider: _customColorsExpanded,
                trailing: Icon(
                  _customColorsExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => setState(
                  () => _customColorsExpanded = !_customColorsExpanded,
                ),
              ),
              if (_customColorsExpanded)
                _ExpandedSettingsBlock(
                  children: [
                    for (final token in ThemeToken.values)
                      SettingsListTile(
                        icon: Icons.palette_outlined,
                        title: _tokenLabel(l10n, token),
                        subtitle: _tokenDescription(l10n, token),
                        showDivider: true,
                        onTap: () => _pickTokenColor(token),
                        trailing: _ColorSwatchButton(
                          color: Color(themeState.tokens.valueOf(token)),
                          onTap: () => _pickTokenColor(token),
                        ),
                      ),
                    _CustomColorActions(
                      onSave: _saveAsThemeColor,
                      onRestore: _notifier.restoreDefaults,
                      saveLabel: l10n.saveAsThemeColor,
                      restoreLabel: l10n.restoreDefaultColors,
                    ),
                  ],
                ),
      ],
    );
  }
}

enum _PackMenuAction { rename, copy, delete }

class _ExpandedSettingsBlock extends StatelessWidget {
  const _ExpandedSettingsBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

class _CustomColorActions extends StatelessWidget {
  const _CustomColorActions({
    required this.onSave,
    required this.onRestore,
    required this.saveLabel,
    required this.restoreLabel,
  });

  final VoidCallback onSave;
  final VoidCallback onRestore;
  final String saveLabel;
  final String restoreLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: context.appBorderRadius,
    );
    ButtonStyle styleFor(Color background) => ButtonStyle(
          shape: WidgetStatePropertyAll(shape),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8),
          ),
          backgroundColor: WidgetStatePropertyAll(background),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

    Widget button({
      required VoidCallback onPressed,
      required Color background,
      required IconData icon,
      required String label,
    }) =>
        FilledButton(
          onPressed: onPressed,
          style: styleFor(background),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: button(
                onPressed: onSave,
                background: scheme.secondaryContainer,
                icon: Icons.bookmark_add_outlined,
                label: saveLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: button(
                onPressed: onRestore,
                background: scheme.surfaceContainerHighest,
                icon: Icons.restart_alt,
                label: restoreLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.appBorderRadius;
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: const SizedBox(width: 28, height: 28),
      ),
    );
  }
}

class _ThemeSlotBadge extends StatelessWidget {
  const _ThemeSlotBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1,
    );
    final fontSize = style?.fontSize ?? 11;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: style,
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: 1,
          forceStrutHeight: true,
          leading: 0,
        ),
      ),
    );
  }
}

Widget? _packTrailing(
  BuildContext context,
  AppLocalizations l10n, {
  required String packId,
  required String lightPackId,
  required String darkPackId,
  required bool isActive,
}) {
  final theme = Theme.of(context);
  final roles = <String>[
    if (packId == lightPackId) l10n.themeSlotLight,
    if (packId == darkPackId) l10n.themeSlotDark,
  ];
  if (roles.isEmpty && !isActive) return null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < roles.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        _ThemeSlotBadge(label: roles[i]),
      ],
      if (isActive) ...[
        if (roles.isNotEmpty) const SizedBox(width: 8),
        Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
      ],
    ],
  );
}

String _themeModeLabel(AppLocalizations l10n, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.system => l10n.themeModeSystem,
      AppThemeMode.light => l10n.themeModeLight,
      AppThemeMode.dark => l10n.themeModeDark,
    };

String _packTitle(AppLocalizations l10n, ThemeColorPack pack) {
  final preset = pack.builtInPreset;
  if (preset == null) return pack.name;
  return switch (preset) {
    ThemePreset.light => l10n.themePresetLight,
    ThemePreset.grey => l10n.themePresetGrey,
    ThemePreset.slate => l10n.themePresetSlate,
    ThemePreset.claude => l10n.themePresetClaude,
    ThemePreset.mint => l10n.themePresetMint,
    ThemePreset.purple => l10n.themePresetPurple,
    ThemePreset.hermes => l10n.themePresetHermes,
    ThemePreset.ocean => l10n.themePresetOcean,
    ThemePreset.darkModern => l10n.themePresetDarkModern,
  };
}

String _tokenLabel(AppLocalizations l10n, ThemeToken token) => switch (token) {
      ThemeToken.editorSurface => l10n.tokenEditorSurface,
      ThemeToken.sidebarSurface => l10n.tokenSidebarSurface,
      ThemeToken.controlSurface => l10n.tokenControlSurface,
      ThemeToken.border => l10n.tokenBorder,
      ThemeToken.divider => l10n.tokenDivider,
      ThemeToken.primaryText => l10n.tokenPrimaryText,
      ThemeToken.mutedText => l10n.tokenMutedText,
      ThemeToken.accent => l10n.tokenAccent,
      ThemeToken.secondaryAccent => l10n.tokenSecondaryAccent,
      ThemeToken.tertiaryAccent => l10n.tokenTertiaryAccent,
      ThemeToken.cursor => l10n.tokenCursor,
      ThemeToken.chatBackground => l10n.tokenChatBackground,
      ThemeToken.characterBubble => l10n.tokenCharacterBubble,
      ThemeToken.userBubble => l10n.tokenUserBubble,
      ThemeToken.chatText => l10n.tokenChatText,
      ThemeToken.dialogueText => l10n.tokenDialogueText,
    };

String _tokenDescription(AppLocalizations l10n, ThemeToken token) =>
    switch (token) {
      ThemeToken.editorSurface => l10n.tokenEditorSurfaceDescription,
      ThemeToken.sidebarSurface => l10n.tokenSidebarSurfaceDescription,
      ThemeToken.controlSurface => l10n.tokenControlSurfaceDescription,
      ThemeToken.border => l10n.tokenBorderDescription,
      ThemeToken.divider => l10n.tokenDividerDescription,
      ThemeToken.primaryText => l10n.tokenPrimaryTextDescription,
      ThemeToken.mutedText => l10n.tokenMutedTextDescription,
      ThemeToken.accent => l10n.tokenAccentDescription,
      ThemeToken.secondaryAccent => l10n.tokenSecondaryAccentDescription,
      ThemeToken.tertiaryAccent => l10n.tokenTertiaryAccentDescription,
      ThemeToken.cursor => l10n.tokenCursorDescription,
      ThemeToken.chatBackground => l10n.tokenChatBackgroundDescription,
      ThemeToken.characterBubble => l10n.tokenCharacterBubbleDescription,
      ThemeToken.userBubble => l10n.tokenUserBubbleDescription,
      ThemeToken.chatText => l10n.tokenChatTextDescription,
      ThemeToken.dialogueText => l10n.tokenDialogueTextDescription,
    };
