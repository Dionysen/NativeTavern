import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/quick_reply.dart';
import '../../providers/quick_reply_providers.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Screen for managing quick replies
class QuickReplyScreen extends ConsumerWidget {
  const QuickReplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(quickReplyConfigProvider);
    final sortedReplies = List<QuickReply>.from(config.replies)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.quickReplies),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.restore),
            tooltip: AppLocalizations.of(context)!.resetToDefault,
            onPressed: () => _showResetDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SettingsSection(
              icon: Icons.quickreply,
              title: AppLocalizations.of(context)!.quickReplies,
              margin: const EdgeInsets.only(bottom: 12),
              children: [
                SettingsSwitchTile(
                  icon: Icons.visibility_outlined,
                  title: AppLocalizations.of(context)!.showQuickReplies,
                  subtitle: AppLocalizations.of(context)!.displayQuickReplyButtons,
                  value: config.showQuickReplies,
                  onChanged: (_) {
                    ref
                        .read(quickReplyConfigProvider.notifier)
                        .toggleShowQuickReplies();
                  },
                ),
                SettingsSwitchTile(
                  icon: Icons.vertical_align_top,
                  title: AppLocalizations.of(context)!.positionAboveInput,
                  subtitle: config.showAboveInput
                      ? AppLocalizations.of(context)!.quickRepliesAboveInput
                      : AppLocalizations.of(context)!.quickRepliesBelowInput,
                  value: config.showAboveInput,
                  showDivider: false,
                  onChanged: config.showQuickReplies
                      ? (_) {
                          ref
                              .read(quickReplyConfigProvider.notifier)
                              .togglePosition();
                        }
                      : null,
                ),
              ],
            ),
          ),

          // Quick replies list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.quickReplies,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppLocalizations.of(context)!.add),
                  onPressed: () => _showEditDialog(context, ref, null),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Reorderable list of quick replies
          Expanded(
            child: sortedReplies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quick_contacts_dialer_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noQuickReplies,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showEditDialog(context, ref, null),
                          child: Text(AppLocalizations.of(context)!
                              .addYourFirstQuickReply),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SettingsGroupedPanel(
                      padding: EdgeInsets.zero,
                      child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: sortedReplies.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      ref
                          .read(quickReplyConfigProvider.notifier)
                          .reorder(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final reply = sortedReplies[index];
                      return _QuickReplyTile(
                        key: ValueKey(reply.id),
                        reply: reply,
                        index: index,
                        showDivider: index < sortedReplies.length - 1,
                        onEdit: () => _showEditDialog(context, ref, reply),
                        onToggle: () {
                          ref
                              .read(quickReplyConfigProvider.notifier)
                              .toggleReply(reply.id);
                        },
                        onDelete: () => _showDeleteDialog(context, ref, reply),
                      );
                    },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, QuickReply? reply) {
    showDialog(
      context: context,
      builder: (context) => _QuickReplyEditDialog(
        reply: reply,
        onSave: (newReply) {
          if (reply == null) {
            ref.read(quickReplyConfigProvider.notifier).addReply(newReply);
          } else {
            ref.read(quickReplyConfigProvider.notifier).updateReply(newReply);
          }
        },
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, QuickReply reply) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteQuickReply),
        content: Text(AppLocalizations.of(context)!
            .deleteQuickReplyQuestion(reply.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(quickReplyConfigProvider.notifier).removeReply(reply.id);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.resetToDefault),
        content: Text(AppLocalizations.of(context)!.resetToDefaultQuestion2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(quickReplyConfigProvider.notifier).resetToDefault();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.reset),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyTile extends StatelessWidget {
  final QuickReply reply;
  final int index;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _QuickReplyTile({
    super.key,
    required this.reply,
    required this.index,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SettingsControlTile(
      dragIndex: index,
      icon: Icons.quickreply_outlined,
      title: reply.label,
      subtitle: reply.message.isEmpty
          ? AppLocalizations.of(context)!.continueOrEmpty
          : reply.message,
      maxSubtitleLines: 1,
      enabled: reply.enabled,
      showDivider: showDivider,
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply.autoSend)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: AppLocalizations.of(context).autoSendTooltip,
                child: Icon(
                  Icons.send,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
            ),
          ThemedSwitch(
            value: reply.enabled,
            onChanged: (_) => onToggle(),
          ),
          AdaptiveActionMenuButton<String>(
            itemBuilder: (context) => [
              AdaptiveActionDrawerItem(
                value: 'edit',
                leading: const Icon(Icons.edit),
                title: Text(AppLocalizations.of(context)!.edit),
              ),
              AdaptiveActionDrawerItem(
                value: 'delete',
                leading: const Icon(Icons.delete),
                title: Text(AppLocalizations.of(context)!.delete),
                destructive: true,
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _QuickReplyEditDialog extends StatefulWidget {
  final QuickReply? reply;
  final Function(QuickReply) onSave;

  const _QuickReplyEditDialog({
    this.reply,
    required this.onSave,
  });

  @override
  State<_QuickReplyEditDialog> createState() => _QuickReplyEditDialogState();
}

class _QuickReplyEditDialogState extends State<_QuickReplyEditDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _messageController;
  late bool _autoSend;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.reply?.label ?? '');
    _messageController =
        TextEditingController(text: widget.reply?.message ?? '');
    _autoSend = widget.reply?.autoSend ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reply != null;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(isEditing
          ? AppLocalizations.of(context)!.editQuickReplyLabel
          : AppLocalizations.of(context)!.addQuickReply),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: l10n.buttonLabel,
                hintText: l10n.buttonLabelHint,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: l10n.message,
                hintText: l10n.leaveEmptyForContinue,
                helperText: l10n.supportsMacros,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.autoSendTooltip),
              subtitle: Text(_autoSend
                  ? l10n.messageSentImmediately
                  : l10n.messageFillsInput),
              value: _autoSend,
              onChanged: (value) => setState(() => _autoSend = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: _labelController.text.trim().isEmpty
              ? null
              : () {
                  final newReply = QuickReply(
                    id: widget.reply?.id ?? const Uuid().v4(),
                    label: _labelController.text.trim(),
                    message: _messageController.text,
                    enabled: widget.reply?.enabled ?? true,
                    order: widget.reply?.order ?? 999,
                    autoSend: _autoSend,
                  );
                  widget.onSave(newReply);
                  Navigator.pop(context);
                },
          child: Text(isEditing
              ? AppLocalizations.of(context)!.save
              : AppLocalizations.of(context)!.add),
        ),
      ],
    );
  }
}
