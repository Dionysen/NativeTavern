import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import '../../../domain/services/slash_command_service.dart';
import '../../theme/app_theme.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Slash command picker content for the composer expansion panel.
///
/// Shell chrome (frost / surface) is provided by the chat composer; this widget
/// matches [ChatChoicePanel] layout: header + themed tappable chips.
class SlashCommandSuggestions extends ConsumerWidget {
  final String input;
  final Function(SlashCommand) onSelect;
  final VoidCallback onDismiss;

  const SlashCommandSuggestions({
    super.key,
    required this.input,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slashService = ref.watch(slashCommandServiceProvider);
    final suggestions = slashService.getSuggestions(input);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.commands,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final command = suggestions[index];
                  return _CommandSuggestionTile(
                    command: command,
                    onTap: () => onSelect(command),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandSuggestionTile extends StatelessWidget {
  final SlashCommand command;
  final VoidCallback onTap;

  const _CommandSuggestionTile({
    required this.command,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ZephyrChatChrome.tappableMenuChip(
      context,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '/${command.name}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (command.aliases.isNotEmpty)
                  Text(
                    l10n.aliasesLabel(
                      command.aliases.map((a) => '/$a').join(', '),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline help dialog for slash commands
class SlashCommandHelpDialog extends ConsumerWidget {
  const SlashCommandHelpDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep provider warm so custom/user commands stay registered.
    ref.watch(slashCommandServiceProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.terminal, color: scheme.primary),
          const SizedBox(width: 8),
          Text(l10n.slashCommands),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: SlashCommands.all.length,
          itemBuilder: (context, index) {
            final command = SlashCommands.all[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '/${command.name}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                      if (command.aliases.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          command.aliases.map((a) => '/$a').join(', '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    command.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    command.usage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTheme.textMuted,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
