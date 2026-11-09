import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/domain/models/tool_generation.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/tool_calling_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

class ToolCallingSettingsScreen extends ConsumerWidget {
  const ToolCallingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(toolCallingSettingsProvider);
    final controller = ref.read(toolCallingSettingsProvider.notifier);
    final descriptors = ref.watch(builtInToolRegistryProvider).descriptors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolCalling)),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.build_outlined,
            title: l10n.toolCalling,
            children: [
              SettingsSwitchTile(
                key: const Key('tool-calling-master-toggle'),
                icon: Icons.build_outlined,
                title: l10n.toolCallingAllow,
                subtitle: l10n.toolCallingAllowSubtitle,
                value: settings.enabled,
                showDivider: false,
                onChanged: controller.setEnabled,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.extension_outlined,
            title: l10n.toolBuiltInTools,
            children: [
              for (var i = 0; i < descriptors.length; i++)
                _BuiltInToolTile(
                  key: Key('built-in-tool-${descriptors[i].definition.name}'),
                  icon: _toolIcon(descriptors[i].definition.name),
                  title: descriptors[i].definition.name,
                  subtitle: descriptors[i].definition.description,
                  value: settings.enabledBuiltInTools.contains(
                    descriptors[i].definition.name,
                  ),
                  enabled: settings.enabled,
                  showDivider: true,
                  onChanged: (value) => controller.setBuiltInEnabled(
                    descriptors[i].definition.name,
                    value,
                  ),
                ),
              SettingsValueTile(
                key: const Key('tool-calling-mcp-link'),
                icon: Icons.extension_outlined,
                title: l10n.toolMcpTools,
                subtitle: l10n.toolMcpPermissionsSubtitle,
                valueText: '',
                showDivider: false,
                onTap: () => context.openShell(AppRoutes.mcpSettings),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.shield_outlined,
            title: l10n.toolSafetyLimits,
            children: [
              _LimitStepper(
                key: const Key('tool-round-limit'),
                icon: Icons.repeat,
                title: l10n.toolRounds,
                value: settings.limits.maxToolRounds,
                minimum: 1,
                maximum: 16,
                showDivider: true,
                onChanged: (value) => controller.setLimits(
                  _limits(settings.limits, maxToolRounds: value),
                ),
              ),
              _LimitStepper(
                key: const Key('tool-call-limit'),
                icon: Icons.numbers,
                title: l10n.toolCallsPerResponse,
                value: settings.limits.maxCalls,
                minimum: 1,
                maximum: 64,
                showDivider: true,
                onChanged: (value) => controller.setLimits(
                  _limits(settings.limits, maxCalls: value),
                ),
              ),
              _LimitStepper(
                key: const Key('tool-time-limit'),
                icon: Icons.timer_outlined,
                title: l10n.toolTimeLimit,
                suffix: l10n.toolSeconds,
                value: settings.limits.maxElapsed.inSeconds,
                minimum: 5,
                maximum: 600,
                step: 5,
                showDivider: true,
                onChanged: (value) => controller.setLimits(
                  _limits(settings.limits, maxElapsedSeconds: value),
                ),
              ),
              _LimitStepper(
                key: const Key('tool-token-limit'),
                icon: Icons.token_outlined,
                title: l10n.toolTokenBudget,
                suffix: l10n.toolTokens,
                value: settings.limits.maxTokenBudget,
                minimum: 256,
                maximum: 65536,
                step: 256,
                showDivider: false,
                onChanged: (value) => controller.setLimits(
                  _limits(settings.limits, maxTokenBudget: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuiltInToolTile extends StatelessWidget {
  const _BuiltInToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      enabled: enabled,
      onTap: enabled ? () => onChanged(!value) : null,
      trailing: Checkbox(
        value: value,
        onChanged: enabled ? (v) => onChanged(v ?? false) : null,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _LimitStepper extends StatelessWidget {
  const _LimitStepper({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    this.step = 1,
    this.suffix,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String? suffix;
  final bool showDivider;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsListTile(
      icon: icon,
      title: title,
      subtitle: suffix == null ? '$value' : '$value $suffix',
      showDivider: showDivider,
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ChromeIconButton(
              onPressed: value <= minimum
                  ? null
                  : () => onChanged((value - step).clamp(minimum, maximum)),
              icon: const Icon(Icons.remove),
              tooltip: l10n.toolDecrease(title),
            ),
            ChromeIconButton(
              onPressed: value >= maximum
                  ? null
                  : () => onChanged((value + step).clamp(minimum, maximum)),
              icon: const Icon(Icons.add),
              tooltip: l10n.toolIncrease(title),
            ),
          ],
        ),
      ),
    );
  }
}

ToolLoopLimits _limits(
  ToolLoopLimits current, {
  int? maxToolRounds,
  int? maxCalls,
  int? maxElapsedSeconds,
  int? maxTokenBudget,
}) {
  return ToolLoopLimits(
    maxToolRounds: maxToolRounds ?? current.maxToolRounds,
    maxCalls: maxCalls ?? current.maxCalls,
    maxElapsed: Duration(
      seconds: maxElapsedSeconds ?? current.maxElapsed.inSeconds,
    ),
    maxTokenBudget: maxTokenBudget ?? current.maxTokenBudget,
  );
}

IconData _toolIcon(String name) => switch (name) {
      'generate_image' => Icons.image_outlined,
      'roll_dice' => Icons.casino_outlined,
      'read_variable' => Icons.data_object,
      'search_world_info' => Icons.manage_search,
      _ => Icons.build_outlined,
    };
