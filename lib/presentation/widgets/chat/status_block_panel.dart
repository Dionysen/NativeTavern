import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/status_block_config.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/status_block_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// Composer-adjacent panel for built-in status (mirrors [ChatChoicePanel]).
class StatusBlockPanel extends ConsumerStatefulWidget {
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
  ConsumerState<StatusBlockPanel> createState() => _StatusBlockPanelState();
}

class _StatusBlockPanelState extends ConsumerState<StatusBlockPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(statusBlockConfigProvider);
    final session = ref.watch(statusBlockSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final canRefresh = config.enabled && !session.isLoading;

    Widget panelHeader() {
      return Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.characterStatus,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: widget.isPinned
                ? l10n.unpinCharacterStatusPanel
                : l10n.pinCharacterStatusPanel,
            isSelected: widget.isPinned,
            onPressed: widget.onTogglePin,
            icon: Icon(
              widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
          ),
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            tooltip: l10n.refresh,
            onPressed: canRefresh ? widget.onRefresh : null,
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
            onPressed: widget.onOpenSettings,
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
                  onPressed: widget.onOpenSettings,
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
              onPressed: widget.onOpenSettings,
              child: Text(l10n.openCharacterStatusSettings),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      key: const ValueKey('status-block-panel'),
      constraints: BoxConstraints(maxHeight: _expanded ? 320 : 56),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            panelHeader(),
            if (_expanded) ...[
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
                    child: StatusBlockBody(snapshot: session.snapshot!),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared field list used by the composer panel and in-bubble card.
class StatusBlockBody extends StatelessWidget {
  const StatusBlockBody({super.key, required this.snapshot});

  final StatusBlockSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final character in snapshot.characters) ...[
          Text(
            character.name.isEmpty ? '—' : character.name,
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
                    text: entry.value,
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
}

/// Collapsible status card rendered inside a message bubble.
class MessageStatusBlockCard extends StatefulWidget {
  const MessageStatusBlockCard({
    super.key,
    required this.snapshot,
    this.title,
  });

  final StatusBlockSnapshot snapshot;
  final String? title;

  @override
  State<MessageStatusBlockCard> createState() => _MessageStatusBlockCardState();
}

class _MessageStatusBlockCardState extends State<MessageStatusBlockCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                child: StatusBlockBody(snapshot: widget.snapshot),
              ),
          ],
        ),
      ),
    );
  }
}
