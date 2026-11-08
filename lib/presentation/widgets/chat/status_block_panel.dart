import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/status_block_config.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/providers/status_block_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// Composer-adjacent panel for built-in status (mirrors [ChatChoicePanel]).
/// Visibility is controlled by the composer button — no inner expand chrome.
class StatusBlockPanel extends ConsumerWidget {
  const StatusBlockPanel({
    super.key,
    required this.onOpenSettings,
    required this.onRefresh,
    required this.isPinned,
    required this.onTogglePin,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;
  final bool isPinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(statusBlockConfigProvider);
    final session = ref.watch(statusBlockSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final canRefresh = config.enabled && !session.isLoading;
    final userName =
        ref.watch(activePersonaProvider).valueOrNull?.name.trim() ?? '';

    Widget panelHeader() {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.characterStatus,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: isPinned
                ? l10n.unpinCharacterStatusPanel
                : l10n.pinCharacterStatusPanel,
            isSelected: isPinned,
            onPressed: onTogglePin,
            icon: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: l10n.refresh,
            onPressed: canRefresh ? onRefresh : null,
            icon: session.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: onOpenSettings,
          ),
        ],
      );
    }

    if (!config.enabled) {
      return Padding(
        key: const ValueKey('status-block-panel-disabled'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.characterStatusDisabledTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  tooltip: l10n.settings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.characterStatusDisabledHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enableCharacterStatus),
              value: false,
              onChanged: (_) async {
                await ref
                    .read(statusBlockConfigProvider.notifier)
                    .setEnabled(true);
              },
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: onOpenSettings,
              child: Text(l10n.openCharacterStatusSettings),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      key: const ValueKey('status-block-panel'),
      constraints: const BoxConstraints(maxHeight: 320),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            panelHeader(),
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
                  l10n.characterStatusGenerateFailed,
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              )
            else if (session.snapshot == null || session.snapshot!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.characterStatusEmpty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: StatusBlockBody(
                    snapshot: session.snapshot!,
                    userDisplayName: userName,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared field list used by the composer panel and in-bubble card.
class StatusBlockBody extends StatelessWidget {
  const StatusBlockBody({
    super.key,
    required this.snapshot,
    this.userDisplayName = '',
    this.characterDisplayName = '',
  });

  final StatusBlockSnapshot snapshot;
  final String userDisplayName;
  final String characterDisplayName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final character in snapshot.characters) ...[
          Text(
            _resolveName(character.name),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          for (final entry in character.fields.entries) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key}: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: _resolveMacros(entry.value),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _resolveName(String raw) {
    final resolved = _resolveMacros(raw).trim();
    if (resolved.isEmpty ||
        resolved == 'User' ||
        resolved == '{{user}}' ||
        resolved == '👤 User') {
      final user = userDisplayName.trim();
      if (user.isNotEmpty) return user;
    }
    return resolved.isEmpty ? '—' : resolved;
  }

  String _resolveMacros(String text) {
    var result = text;
    final user = userDisplayName.trim();
    final character = characterDisplayName.trim();
    if (user.isNotEmpty) {
      result = result.replaceAll('{{user}}', user);
      result = result.replaceAll('{{persona}}', user);
    }
    if (character.isNotEmpty) {
      result = result.replaceAll('{{char}}', character);
      result = result.replaceAll('{{charname}}', character);
    }
    return result;
  }
}

/// Collapsible status card rendered inside a message bubble.
class MessageStatusBlockCard extends ConsumerStatefulWidget {
  const MessageStatusBlockCard({
    super.key,
    required this.snapshot,
    this.title,
    this.characterDisplayName = '',
  });

  final StatusBlockSnapshot snapshot;
  final String? title;
  final String characterDisplayName;

  @override
  ConsumerState<MessageStatusBlockCard> createState() =>
      _MessageStatusBlockCardState();
}

class _MessageStatusBlockCardState
    extends ConsumerState<MessageStatusBlockCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final userName =
        ref.watch(activePersonaProvider).valueOrNull?.name.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.title ?? l10n.characterStatus,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: StatusBlockBody(
                  snapshot: widget.snapshot,
                  userDisplayName: userName,
                  characterDisplayName: widget.characterDisplayName,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
