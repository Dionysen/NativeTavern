import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/chat_choice_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';

class ChatChoicePanel extends ConsumerWidget {
  const ChatChoicePanel({
    super.key,
    required this.onSelectChoice,
    required this.onOpenSettings,
  });

  final ValueChanged<String> onSelectChoice;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(chatChoiceConfigProvider);
    final session = ref.watch(chatChoiceSessionProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!config.enabled) {
      return Padding(
        key: const ValueKey('chat-choice-panel-disabled'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.replyChoicesDisabledTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.replyChoicesDisabledHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enableReplyChoices),
              value: false,
              onChanged: (_) async {
                await ref
                    .read(chatChoiceConfigProvider.notifier)
                    .setEnabled(true);
              },
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: onOpenSettings,
              child: Text(l10n.openReplyChoicesSettings),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      key: const ValueKey('chat-choice-panel'),
      constraints: const BoxConstraints(maxHeight: 280),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.replyChoices,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.settings,
                icon: const Icon(Icons.settings_outlined, size: 20),
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (session.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (session.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.replyChoicesGenerateFailed,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            )
          else if (session.choices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.replyChoicesEmpty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final choice in session.choices) ...[
                      InkWell(
                        onTap: () => onSelectChoice(choice),
                        borderRadius:
                            BorderRadius.circular(context.appCornerRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: ZephyrChatChrome.menuChip(context),
                          child: Text(
                            choice,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
