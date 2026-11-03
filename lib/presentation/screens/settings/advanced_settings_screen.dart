import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Advanced settings screen for full sampler control
class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(llmConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedSettings),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefaults,
            onPressed: () => _showResetConfirmation(context, ref),
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.science_outlined,
            title: l10n.basicSampling,
            footer: l10n.sendParametersHint,
            children: [
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.temperature,
                title: l10n.temperature,
                subtitle: l10n.temperatureDescription,
                value: config.temperature,
                min: 0.0,
                max: 2.0,
                divisions: 40,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTemperature(v),
              ),
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.topP,
                title: l10n.topPNucleusSampling,
                subtitle: l10n.topPDescription,
                value: config.topP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTopP(v),
              ),
              _buildIntSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.topK,
                title: l10n.topK,
                subtitle: l10n.topKDescription,
                value: config.topK,
                min: 0,
                max: 200,
                showDivider: false,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTopK(v),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.tune,
            title: l10n.advancedSampling,
            children: [
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.minP,
                title: l10n.minP,
                subtitle: l10n.minPDescription,
                value: config.minP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateMinP(v),
              ),
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.typicalP,
                title: l10n.typicalP,
                subtitle: l10n.typicalPDescription,
                value: config.typicalP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTypicalP(v),
              ),
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.topA,
                title: l10n.topA,
                subtitle: l10n.topADescription,
                value: config.topA,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTopA(v),
              ),
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.tailFreeSampling,
                title: l10n.tailFreeSamplingTfs,
                subtitle: l10n.tfsDescription,
                value: config.tailFreeSampling,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                showDivider: false,
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updateTailFreeSampling(v),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.repeat,
            title: l10n.repetitionControl,
            children: [
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.repetitionPenalty,
                title: l10n.repetitionPenalty,
                subtitle: l10n.repetitionPenaltyDescription,
                value: config.repetitionPenalty,
                min: 1.0,
                max: 2.0,
                divisions: 20,
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updateRepetitionPenalty(v),
              ),
              _buildIntSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.repetitionPenaltyRange,
                title: l10n.repetitionPenaltyRange,
                subtitle: l10n.repetitionPenaltyRangeDescription,
                value: config.repetitionPenaltyRange,
                min: 0,
                max: 4096,
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updateRepetitionPenaltyRange(v),
              ),
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.frequencyPenalty,
                title: l10n.frequencyPenalty,
                subtitle: l10n.frequencyPenaltyDescription,
                value: config.frequencyPenalty,
                min: 0.0,
                max: 2.0,
                divisions: 40,
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updateFrequencyPenalty(v),
              ),
              _buildSliderTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.presencePenalty,
                title: l10n.presencePenalty,
                subtitle: l10n.presencePenaltyDescription,
                value: config.presencePenalty,
                min: 0.0,
                max: 2.0,
                divisions: 40,
                showDivider: false,
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updatePresencePenalty(v),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.auto_graph,
            title: l10n.mirostatLocalModels,
            children: [
              _buildMirostatModeTile(context, ref, config.mirostatMode),
              if (config.mirostatMode > 0) ...[
                _buildSliderTile(
                  context: context,
                  ref: ref,
                  title: l10n.mirostatTau,
                  subtitle: l10n.mirostatTauDescription,
                  value: config.mirostatTau,
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateMirostatTau(v),
                ),
                _buildSliderTile(
                  context: context,
                  ref: ref,
                  title: l10n.mirostatEta,
                  subtitle: l10n.mirostatEtaDescription,
                  value: config.mirostatEta,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  showDivider: false,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateMirostatEta(v),
                ),
              ],
            ],
          ),
          SettingsSection(
            icon: Icons.compress,
            title: l10n.contextManagement,
            children: [
              _buildAutoSummarizeTile(context, ref, config.autoSummarizeEnabled),
              if (config.autoSummarizeEnabled)
                _buildSliderTile(
                  context: context,
                  ref: ref,
                  title: l10n.autoSummarizeThreshold,
                  subtitle: l10n.autoSummarizeThresholdDescription,
                  value: config.autoSummarizeThreshold,
                  min: 0.5,
                  max: 0.95,
                  divisions: 9,
                  showDivider: false,
                  onChanged: (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updateAutoSummarizeThreshold(v),
                ),
            ],
          ),
          SettingsSection(
            icon: Icons.bolt_outlined,
            title: l10n.generationControl,
            children: [
              _buildIntInputTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.maxTokens,
                title: l10n.maxTokens,
                subtitle: l10n.maxTokensDescription,
                value: config.maxTokens,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateMaxTokens(v),
              ),
              _buildIntInputTile(
                context: context,
                ref: ref,
                parameter: SamplerParameters.seed,
                title: l10n.seed,
                subtitle: l10n.seedDescription,
                value: config.seed,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateSeed(v),
              ),
              _buildStopSequencesTile(context, ref, config.stopSequences),
            ],
          ),
        ],
      ),
    );
  }

  /// Leading checkbox controlling whether a request-body parameter is sent.
  /// Returns an empty box when the row is not a provider parameter.
  Widget _buildParameterCheckbox(
    BuildContext context,
    WidgetRef ref,
    String? parameter,
  ) {
    if (parameter == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(llmConfigProvider).sendsParameter(parameter);
    return Tooltip(
      message: l10n.sendParameterTooltip,
      child: Checkbox(
        value: enabled,
        onChanged: (checked) => ref
            .read(llmConfigProvider.notifier)
            .updateParameterEnabled(parameter, checked ?? true),
      ),
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? parameter,
    bool showDivider = true,
  }) {
    final enabled = parameter == null ||
        ref.watch(llmConfigProvider).sendsParameter(parameter);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              _buildParameterCheckbox(context, ref, parameter),
              const SizedBox(width: 4),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildIntSliderTile({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    String? parameter,
    bool showDivider = true,
  }) {
    final enabled = parameter == null ||
        ref.watch(llmConfigProvider).sendsParameter(parameter);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              _buildParameterCheckbox(context, ref, parameter),
              const SizedBox(width: 4),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Text(
                value.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: enabled ? (v) => onChanged(v.round()) : null,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildMirostatModeTile(BuildContext context, WidgetRef ref, int mode) {
    final l10n = AppLocalizations.of(context);
    final showDivider = mode > 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              _buildParameterCheckbox(
                  context, ref, SamplerParameters.mirostat),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.mirostatMode,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      l10n.adaptiveSamplingForLocalModels,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.off)),
                  const ButtonSegment(value: 1, label: Text('v1')),
                  const ButtonSegment(value: 2, label: Text('v2')),
                ],
                selected: {mode},
                onSelectionChanged: (selected) {
                  ref
                      .read(llmConfigProvider.notifier)
                      .updateMirostatMode(selected.first);
                },
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildAutoSummarizeTile(
      BuildContext context, WidgetRef ref, bool enabled) {
    final l10n = AppLocalizations.of(context);
    return SettingsSwitchTile(
      icon: Icons.compress,
      title: l10n.autoSummarize,
      subtitle: l10n.autoSummarizeDescription,
      value: enabled,
      showDivider: enabled,
      onChanged: (value) {
        ref.read(llmConfigProvider.notifier).updateAutoSummarizeEnabled(value);
      },
    );
  }

  Widget _buildIntInputTile({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
    String? parameter,
    bool showDivider = true,
  }) {
    final enabled = parameter == null ||
        ref.watch(llmConfigProvider).sendsParameter(parameter);
    return SettingsListTile(
      icon: Icons.tag,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      enabled: enabled,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildParameterCheckbox(context, ref, parameter),
          Text(
            value.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      onTap: enabled
          ? () => _showIntInputDialog(context, title, value, onChanged)
          : null,
    );
  }

  void _showIntInputDialog(
    BuildContext context,
    String title,
    int currentValue,
    ValueChanged<int> onChanged,
  ) {
    final controller = TextEditingController(text: currentValue.toString());
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) {
                onChanged(value);
              }
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSequencesTile(
    BuildContext context,
    WidgetRef ref,
    List<String> sequences,
  ) {
    final l10n = AppLocalizations.of(context);
    return SettingsListTile(
      icon: Icons.stop_circle_outlined,
      title: l10n.stopSequences,
      subtitle: sequences.isEmpty
          ? l10n.noStopSequencesConfigured
          : sequences.join(', '),
      showDivider: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildParameterCheckbox(context, ref, SamplerParameters.stop),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
      onTap: () => _showStopSequencesDialog(context, ref, sequences),
    );
  }

  void _showStopSequencesDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currentSequences,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: currentSequences.join('\n'),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stopSequences),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stopSequencesDescription,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g.\n\\n\\n\n[END]\n</s>',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final sequences = controller.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              ref
                  .read(llmConfigProvider.notifier)
                  .updateStopSequences(sequences);
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetToDefaults),
        content: Text(l10n.resetConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(llmConfigProvider.notifier).resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsResetToDefaults)),
              );
            },
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }
}
