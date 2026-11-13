import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

enum _ModelThinkingStep { model, effort }

/// Bottom drawer: choose model, then reasoning effort.
class ModelThinkingDrawer extends ConsumerStatefulWidget {
  const ModelThinkingDrawer({super.key});

  @override
  ConsumerState<ModelThinkingDrawer> createState() =>
      _ModelThinkingDrawerState();
}

class _ModelThinkingDrawerState extends ConsumerState<ModelThinkingDrawer> {
  final _searchController = TextEditingController();
  _ModelThinkingStep _step = _ModelThinkingStep.model;
  List<String> _models = const [];
  List<String> _filteredModels = const [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterModels);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModels());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final l10n = AppLocalizations.of(context);
    final llmConfig = ref.read(llmConfigProvider);
    final llmService = ref.read(llmServiceProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final models = await llmService.getAvailableModels(llmConfig);
      if (!mounted) return;
      setState(() {
        _models = models;
        _filteredModels = models;
        _loading = false;
        if (models.isEmpty) {
          _error = l10n.noModelsAvailable;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = l10n.failedToLoadModels(e.toString());
      });
    }
  }

  void _filterModels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredModels = query.isEmpty
          ? _models
          : _models
              .where((model) => model.toLowerCase().contains(query))
              .toList();
    });
  }

  void _selectModel(String model) {
    final current = ref.read(llmConfigProvider).model;
    if (model != current) {
      ref.read(llmConfigProvider.notifier).updateModel(model);
    }
    setState(() => _step = _ModelThinkingStep.effort);
  }

  void _selectEffort(String effort) {
    ref.read(llmConfigProvider.notifier).updateReasoningEffort(effort);
    Navigator.of(context).pop();
  }

  String _effortLabel(AppLocalizations l10n, String effort) => switch (effort) {
        ReasoningEffort.auto => l10n.effortAuto,
        ReasoningEffort.min => l10n.effortMin,
        ReasoningEffort.low => l10n.effortLow,
        ReasoningEffort.medium => l10n.effortMedium,
        ReasoningEffort.high => l10n.effortHigh,
        ReasoningEffort.max => l10n.effortMax,
        _ => effort,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final llmConfig = ref.watch(llmConfigProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final title = _step == _ModelThinkingStep.model
        ? l10n.selectModel
        : l10n.reasoningEffort;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  if (_step == _ModelThinkingStep.effort)
                    ChromeIconButton(
                      density: ChromeIconButtonDensity.compact,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () =>
                          setState(() => _step = _ModelThinkingStep.model),
                      icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                  if (_step == _ModelThinkingStep.effort)
                    const SizedBox(width: 4),
                  Icon(
                    _step == _ModelThinkingStep.model
                        ? Icons.smart_toy_rounded
                        : Icons.psychology_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (_step == _ModelThinkingStep.model) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '${l10n.provider}: ${llmConfig.provider.name}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: ZephyrChatChrome.inputFieldDecoration(
                    context,
                    hintText: l10n.searchModels,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ).copyWith(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(child: _buildStepBody(l10n, scheme, llmConfig)),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody(
    AppLocalizations l10n,
    ColorScheme scheme,
    LLMConfig llmConfig,
  ) {
    if (_step == _ModelThinkingStep.effort) {
      final current = ReasoningEffort.values.contains(llmConfig.reasoningEffort)
          ? llmConfig.reasoningEffort
          : ReasoningEffort.auto;
      return ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final effort in ReasoningEffort.values)
            ListTile(
              leading: Icon(
                effort == current ? Icons.check_circle : Icons.circle_outlined,
                color: effort == current
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                size: 20,
              ),
              title: Text(_effortLabel(l10n, effort)),
              selected: effort == current,
              selectedTileColor: scheme.primary.withValues(alpha: 0.1),
              onTap: () => _selectEffort(effort),
            ),
        ],
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loadingModels),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadModels,
                child: Text(l10n.retry),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _step = _ModelThinkingStep.effort),
                child: Text(l10n.reasoningEffort),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredModels.isEmpty) {
      return Center(
        child: Text(
          l10n.noModelsMatchSearch,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _filteredModels.length,
      itemBuilder: (context, index) {
        final model = _filteredModels[index];
        final isSelected = model == llmConfig.model;
        return ListTile(
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            size: 20,
          ),
          title: Text(
            model,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? scheme.primary : scheme.onSurface,
            ),
          ),
          selected: isSelected,
          selectedTileColor: scheme.primary.withValues(alpha: 0.1),
          onTap: () => _selectModel(model),
        );
      },
    );
  }
}
