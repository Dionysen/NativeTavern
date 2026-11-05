import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/chat_choice_config.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/chat_choice_providers.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

class ChatChoiceSettingsScreen extends ConsumerStatefulWidget {
  const ChatChoiceSettingsScreen({super.key});

  @override
  ConsumerState<ChatChoiceSettingsScreen> createState() =>
      _ChatChoiceSettingsScreenState();
}

class _ChatChoiceSettingsScreenState
    extends ConsumerState<ChatChoiceSettingsScreen> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: ref.read(chatChoiceConfigProvider).promptTemplate,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(chatChoiceConfigProvider);
    final slots = config.normalizedSlots();
    final notifier = ref.read(chatChoiceConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.replyChoices),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefault,
            onPressed: () async {
              await notifier.resetToDefault();
              if (mounted) {
                _promptController.text =
                    ref.read(chatChoiceConfigProvider).promptTemplate;
              }
            },
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.grading_outlined,
            title: l10n.replyChoices,
            children: [
              SettingsSwitchTile(
                icon: Icons.toggle_on_outlined,
                title: l10n.enableReplyChoices,
                subtitle: l10n.enableReplyChoicesHint,
                value: config.enabled,
                onChanged: (value) => notifier.setEnabled(value),
              ),
              SettingsValueTile(
                icon: Icons.format_list_numbered,
                title: l10n.replyChoiceCount,
                valueText: '${config.choiceCount}',
                onTap: () => _pickChoiceCount(context, config.choiceCount),
              ),
              SettingsValueTile(
                icon: Icons.short_text,
                title: l10n.replyChoiceMaxChars,
                valueText: '${config.maxCharsPerChoice}',
                showDivider: false,
                onTap: () => _pickMaxChars(context, config.maxCharsPerChoice),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.code,
            title: l10n.replyChoicePromptTemplate,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l10n.replyChoicePromptPlaceholders,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _promptController,
                  maxLines: 10,
                  minLines: 6,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: ChatChoiceConfig.defaultPromptTemplate,
                  ),
                  onChanged: notifier.setPromptTemplate,
                ),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.tune,
            title: l10n.replyChoiceTendencies,
            children: [
              for (var i = 0; i < slots.length; i++)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    i == 0 ? 8 : 0,
                    16,
                    i == slots.length - 1 ? 16 : 8,
                  ),
                  child: TextFormField(
                    key: ValueKey('choice-slot-$i'),
                    initialValue: slots[i].tendency,
                    decoration: InputDecoration(
                      labelText: l10n.replyChoiceTendencyLabel(i + 1),
                      hintText: l10n.replyChoiceTendencyHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        notifier.updateSlotTendency(i, value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickChoiceCount(BuildContext context, int current) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.replyChoiceCount),
          children: [
            for (var n = ChatChoiceConfig.minChoiceCount;
                n <= ChatChoiceConfig.maxChoiceCount;
                n++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, n),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontWeight: n == current ? FontWeight.bold : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (picked != null) {
      await ref.read(chatChoiceConfigProvider.notifier).setChoiceCount(picked);
    }
  }

  Future<void> _pickMaxChars(BuildContext context, int current) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: '$current');
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.replyChoiceMaxChars),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref
          .read(chatChoiceConfigProvider.notifier)
          .setMaxCharsPerChoice(picked);
    }
  }
}
