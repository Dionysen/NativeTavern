import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/domain/services/image_prompt_composer.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';

/// Confirmed generation request from the dialog; chat runs it asynchronously.
class ImageGenDialogLaunch {
  final ImageGenRequest request;

  const ImageGenDialogLaunch(this.request);
}

/// Dialog for composing an image prompt before async generation in chat.
class ImageGenerationDialog extends ConsumerStatefulWidget {
  /// The base prompt (usually from message content)
  final String basePrompt;

  /// Optional character name for context
  final String? characterName;

  /// Fixed character appearance tags (not rewritten by the LLM).
  final String? characterAppearance;

  /// Fixed user/persona appearance tags.
  final String? personaAppearance;

  /// The generation mode
  final ImageGenMode mode;

  /// When true, ask the chat model to fill the prompt after the dialog opens.
  final bool autoCompose;

  const ImageGenerationDialog({
    super.key,
    required this.basePrompt,
    this.characterName,
    this.characterAppearance,
    this.personaAppearance,
    this.mode = ImageGenMode.free,
    this.autoCompose = false,
  });

  @override
  ConsumerState<ImageGenerationDialog> createState() =>
      _ImageGenerationDialogState();

  /// Show the dialog and return a launch request (if confirmed).
  static Future<ImageGenDialogLaunch?> show(
    BuildContext context, {
    required String basePrompt,
    String? characterName,
    String? characterAppearance,
    String? personaAppearance,
    ImageGenMode mode = ImageGenMode.free,
    bool autoCompose = false,
  }) {
    return showDialog<ImageGenDialogLaunch>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ImageGenerationDialog(
        basePrompt: basePrompt,
        characterName: characterName,
        characterAppearance: characterAppearance,
        personaAppearance: personaAppearance,
        mode: mode,
        autoCompose: autoCompose,
      ),
    );
  }
}

class _ImageGenerationDialogState extends ConsumerState<ImageGenerationDialog> {
  late TextEditingController _promptController;
  late TextEditingController _negativePromptController;
  bool _isComposingPrompt = false;
  String? _error;
  final _composer = const ImagePromptComposer();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(imageGenSettingsProvider);
    _promptController = TextEditingController(text: _buildInitialPrompt());
    _negativePromptController = TextEditingController(
      text: settings.effectiveNegativePrompt,
    );
    if (widget.autoCompose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fillPromptWithAi();
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    super.dispose();
  }

  String _buildInitialPrompt() {
    final basePrompt = widget.basePrompt.trim();

    switch (widget.mode) {
      case ImageGenMode.character:
        return 'full body portrait, ${widget.characterName ?? "character"}, $basePrompt';
      case ImageGenMode.face:
        return 'close up portrait, ${widget.characterName ?? "character"}, $basePrompt';
      case ImageGenMode.background:
        return 'background, scene, $basePrompt';
      case ImageGenMode.lastMessage:
      case ImageGenMode.scenario:
      case ImageGenMode.free:
        return basePrompt;
    }
  }

  InputDecoration _fieldDecoration({
    required ColorScheme scheme,
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(imageGenSettingsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.image, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.generateImagesUsingAi)),
          if (!settings.enabled)
            Tooltip(
              message: l10n.notConfigured,
              child: Icon(
                Icons.warning_amber_rounded,
                color: scheme.tertiary,
                size: 20,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.provider.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '${settings.defaultWidth}x${settings.defaultHeight}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildModelSelector(settings, scheme, theme),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    l10n.prompt,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('image-gen-fill-prompt'),
                    onPressed: _isComposingPrompt ? null : _fillPromptWithAi,
                    icon: _isComposingPrompt
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(l10n.fillImagePromptWithAi),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _promptController,
                maxLines: 4,
                decoration: _fieldDecoration(
                  scheme: scheme,
                  hintText: l10n.enterPromptToGenerate,
                ),
                enabled: !_isComposingPrompt,
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  l10n.negativePrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    controller: _negativePromptController,
                    maxLines: 2,
                    style: theme.textTheme.bodySmall,
                    decoration: _fieldDecoration(
                      scheme: scheme,
                      hintText: l10n.enterTermsToAvoid,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: scheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _isComposingPrompt || !settings.enabled
              ? null
              : _confirmLaunch,
          icon: const Icon(Icons.auto_awesome),
          label: Text(l10n.generate),
        ),
      ],
    );
  }

  Future<void> _fillPromptWithAi() async {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(llmConfigProvider);
    if (config.apiKey.isEmpty && config.apiUrl.isEmpty) {
      setState(() => _error = l10n.configureNow);
      return;
    }

    setState(() {
      _isComposingPrompt = true;
      _error = null;
    });

    try {
      final sceneText = widget.basePrompt.trim().isEmpty
          ? _promptController.text
          : widget.basePrompt;
      final settings = ref.read(imageGenSettingsProvider);
      final generated = await ref.read(llmServiceProvider).generate(
            _composer.composeMessages(
              sceneText: sceneText,
              characterName: widget.characterName,
              instruction: settings.effectiveLlmImagePromptInstruction,
              characterAppearance: widget.characterAppearance,
              personaAppearance: widget.personaAppearance,
            ),
            config,
          );
      final prompt = _composer.normalizeModelOutput(generated);
      if (!mounted) return;
      _promptController.text = prompt.isEmpty
          ? _composer.fallbackPrompt(
              sceneText: sceneText,
              characterName: widget.characterName,
            )
          : prompt;
    } catch (error) {
      if (!mounted) return;
      _promptController.text = _composer.fallbackPrompt(
        sceneText: widget.basePrompt,
        characterName: widget.characterName,
      );
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isComposingPrompt = false);
      }
    }
  }

  void _confirmLaunch() {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(imageGenSettingsProvider);
    final sceneTags = _promptController.text.trim();
    if (sceneTags.isEmpty) {
      setState(() => _error = l10n.enterPromptToGenerate);
      return;
    }

    final availableModels = ref.read(availableModelsProvider);
    final selectedModel = availableModels.contains(settings.model)
        ? settings.model
        : (availableModels.isNotEmpty ? availableModels.first : settings.model);
    if (selectedModel.isNotEmpty && selectedModel != settings.model) {
      ref.read(imageGenSettingsProvider.notifier).setModel(selectedModel);
    }

    final assembled = _composer.assembleFinalPrompt(
      sceneTags: sceneTags,
      commonPrefix: settings.effectiveCommonPromptPrefix,
      characterAppearance: widget.characterAppearance,
      personaAppearance: widget.personaAppearance,
    );

    Navigator.of(context).pop(
      ImageGenDialogLaunch(
        ImageGenRequest(
          prompt: assembled,
          negativePrompt: _negativePromptController.text.isNotEmpty
              ? _negativePromptController.text
              : settings.effectiveNegativePrompt,
          width: settings.defaultWidth,
          height: settings.defaultHeight,
          steps: settings.defaultSteps,
          cfgScale: settings.defaultCfgScale,
          sampler: settings.defaultSampler,
          scheduler: settings.defaultScheduler,
          mode: widget.mode,
          model: selectedModel,
        ),
      ),
    );
  }

  Widget _buildModelSelector(
    ImageGenSettings settings,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final availableModels = ref.watch(availableModelsProvider);
    final currentModel = settings.model;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Icon(Icons.memory, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '${l10n.model}:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableModels.contains(currentModel)
                    ? currentModel
                    : null,
                isExpanded: true,
                isDense: true,
                dropdownColor: scheme.surfaceContainerHigh,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
                hint: Text(
                  currentModel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                items: availableModels.map((model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(
                      model,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setModel(value);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
