import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';

/// Screen for image generation settings
class ImageGenSettingsScreen extends ConsumerWidget {
  const ImageGenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageGenSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.imageGeneration),
        actions: [
          ChromeIconButton(
            icon: const Icon(Icons.restore),
            tooltip: AppLocalizations.of(context)!.resetToDefaults,
            onPressed: () {
              ref.read(imageGenSettingsProvider.notifier).reset();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.settingsResetToDefaults)),
              );
            },
          ),
        ],
      ),
      body: SettingsPageBody(
        children: [
          SettingsSection(
            icon: Icons.toggle_on_outlined,
            title: AppLocalizations.of(context)!.general,
            children: [
              SettingsSwitchTile(
                icon: Icons.image,
                title: AppLocalizations.of(context)!.enableImageGeneration,
                subtitle: AppLocalizations.of(context)!.generateImagesUsingAi,
                value: settings.enabled,
                showDivider: false,
                onChanged: (value) {
                  ref.read(imageGenSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),

          SettingsSection(
            icon: Icons.cloud_outlined,
            title: AppLocalizations.of(context)!.provider,
            children: [
              SettingsChoiceTile<ImageGenProvider>(
                icon: Icons.image_search,
                title: AppLocalizations.of(context)!.imageGenerationProvider,
                selected: settings.provider,
                enabled: settings.enabled,
                choices: [
                  for (final provider in ImageGenProvider.values)
                    SettingsChoice(
                      value: provider,
                      label: provider.displayName,
                    ),
                ],
                valueLabel: settings.provider.displayName,
                onSelected: (value) {
                  ref.read(imageGenSettingsProvider.notifier).setProvider(value);
                },
              ),
              SettingsListTile(
                icon: Icons.link,
                title: AppLocalizations.of(context)!.apiEndpoint,
                subtitle: settings.apiEndpoint?.isNotEmpty == true
                    ? settings.apiEndpoint!
                    : AppLocalizations.of(context)!.notConfigured,
                trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                enabled: settings.enabled,
                onTap: settings.enabled
                    ? () => _showEndpointDialog(context, ref, settings)
                    : null,
              ),
              if (settings.provider.requiresApiKey)
                SettingsListTile(
                  icon: Icons.key_outlined,
                  title: AppLocalizations.of(context)!.apiKey,
                  subtitle: settings.apiKey?.isNotEmpty == true
                      ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                      : AppLocalizations.of(context)!.notConfigured,
                  trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                  enabled: settings.enabled,
                  onTap: settings.enabled
                      ? () => _showApiKeyDialog(context, ref, settings)
                      : null,
                ),
              _buildModelSelector(context, ref, settings),
            ],
          ),

          const SizedBox(height: 16),

          // Default parameters
          SettingsSection(
            icon: Icons.settings_outlined,
            title: AppLocalizations.of(context)!.defaultParameters,
            children: [
              // Size presets
              ListTile(
                title: Text(AppLocalizations.of(context)!.imageSize),
                subtitle: Text(
                    '${settings.defaultWidth} × ${settings.defaultHeight}'),
                trailing: DropdownButton<ImageAspectRatio>(
                  value: ImageAspectRatio.presets.firstWhere(
                    (p) =>
                        p.width == settings.defaultWidth &&
                        p.height == settings.defaultHeight,
                    orElse: () => ImageAspectRatio.presets.first,
                  ),
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(imageGenSettingsProvider.notifier)
                                .setDefaultWidth(value.width);
                            ref
                                .read(imageGenSettingsProvider.notifier)
                                .setDefaultHeight(value.height);
                          }
                        }
                      : null,
                  items: ImageAspectRatio.presets.map((preset) {
                    return DropdownMenuItem(
                      value: preset,
                      child: Text(preset.name),
                    );
                  }).toList(),
                ),
              ),

              // Steps slider
              ListTile(
                title: Text(AppLocalizations.of(context)!.steps),
                subtitle: Slider(
                  value: settings.defaultSteps.toDouble(),
                  min: 1,
                  max: 150,
                  divisions: 149,
                  label: '${settings.defaultSteps}',
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setDefaultSteps(value.round());
                        }
                      : null,
                ),
                trailing: Text(
                  '${settings.defaultSteps}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              // CFG Scale slider
              ListTile(
                title: Text(AppLocalizations.of(context)!.cfgScale),
                subtitle: Slider(
                  value: settings.defaultCfgScale,
                  min: 1.0,
                  max: 30.0,
                  divisions: 58,
                  label: settings.defaultCfgScale.toStringAsFixed(1),
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setDefaultCfgScale(value);
                        }
                      : null,
                ),
                trailing: Text(
                  settings.defaultCfgScale.toStringAsFixed(1),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              // Sampler dropdown
              ListTile(
                title: Text(AppLocalizations.of(context)!.sampler),
                subtitle: Text(
                  ImageGenSampler.samplers
                      .firstWhere(
                        (s) => s.id == settings.defaultSampler,
                        orElse: () => ImageGenSampler.samplers.first,
                      )
                      .name,
                ),
                trailing: DropdownButton<String>(
                  value: settings.defaultSampler,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(imageGenSettingsProvider.notifier)
                                .setDefaultSampler(value);
                          }
                        }
                      : null,
                  items: ImageGenSampler.samplers.map((sampler) {
                    return DropdownMenuItem(
                      value: sampler.id,
                      child: Text(sampler.name),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Scene prompt layers (SillyTavern-style)
          SettingsSection(
            icon: Icons.layers_outlined,
            title: '场景提示词',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: TextEditingController(
                    text: settings.commonPromptPrefix.isEmpty
                        ? settings.effectiveCommonPromptPrefix
                        : settings.commonPromptPrefix,
                  ),
                  decoration: const InputDecoration(
                    labelText: '质量前缀',
                    hintText: '可用 {prompt} 包住场景标签',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setCommonPromptPrefix(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: TextEditingController(
                    text: settings.personaAppearancePrefix,
                  ),
                  decoration: const InputDecoration(
                    labelText: '主角外貌标签',
                    hintText: '例如 1boy, short black hair, brown eyes',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setPersonaAppearancePrefix(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: TextEditingController(
                    text: settings.defaultNegativePrompt?.isNotEmpty == true
                        ? settings.defaultNegativePrompt
                        : settings.effectiveNegativePrompt,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.defaultNegativePrompt,
                    hintText: AppLocalizations.of(context)!.enterTermsToAvoid,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setDefaultNegativePrompt(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: TextEditingController(
                    text: settings.llmImagePromptInstruction.isEmpty
                        ? settings.effectiveLlmImagePromptInstruction
                        : settings.llmImagePromptInstruction,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'AI 写 tag 的说明',
                    hintText: '要求只输出逗号分隔的 Danbooru tag',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setLlmImagePromptInstruction(value);
                  },
                ),
              ),
            ],
          ),

          // NovelAI specific settings
          if (settings.provider == ImageGenProvider.novelai)
            SettingsSection(
            icon: Icons.settings_outlined,
            title: AppLocalizations.of(context).novelAiSettings,
            children: [
                SettingsSwitchTile(
                  icon: Icons.shield_outlined,
                  title: AppLocalizations.of(context).anlasGuard,
                  subtitle: AppLocalizations.of(context).anlasGuardDescription,
                  value: settings.novelaiAnlasGuard,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setNovelaiAnlasGuard(value);
                        }
                      : null,
                ),
                SettingsSwitchTile(
                  icon: Icons.blur_on,
                  title: AppLocalizations.of(context).smea,
                  subtitle: AppLocalizations.of(context).smeaDescription,
                  value: settings.novelaiSm,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setNovelaiSm(value);
                        }
                      : null,
                ),
                if (settings.novelaiSm)
                  SettingsSwitchTile(
                    icon: Icons.auto_fix_high,
                    title: AppLocalizations.of(context).smeaDynamic,
                    subtitle: AppLocalizations.of(context).smeaDynamicDescription,
                    value: settings.novelaiSmDyn,
                    onChanged: settings.enabled
                        ? (value) {
                            ref
                                .read(imageGenSettingsProvider.notifier)
                                .setNovelaiSmDyn(value);
                          }
                        : null,
                  ),
                SettingsSwitchTile(
                  icon: Icons.high_quality,
                  title: AppLocalizations.of(context).decrisper,
                  subtitle: AppLocalizations.of(context).decrisperDescription,
                  value: settings.novelaiDecrisper,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setNovelaiDecrisper(value);
                        }
                      : null,
                ),
                SettingsSwitchTile(
                  icon: Icons.shuffle,
                  title: AppLocalizations.of(context).varietyPlus,
                  subtitle: AppLocalizations.of(context).varietyPlusDescription,
                  value: settings.novelaiVarietyBoost,
                  showDivider: false,
                  onChanged: settings.enabled
                      ? (value) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setNovelaiVarietyBoost(value);
                        }
                      : null,
                ),
              ],
            ),

          // OpenAI (gpt-image) specific settings
          if (settings.provider == ImageGenProvider.openai)
            SettingsSection(
            icon: Icons.settings_outlined,
            title: AppLocalizations.of(context)!.gptImageSettings,
            children: [
                SettingsChoiceTile<String>(
                  icon: Icons.high_quality,
                  title: AppLocalizations.of(context)!.qualityLabel,
                  subtitle: settings.openaiQuality == 'hd'
                      ? AppLocalizations.of(context)!.qualityHighDescription
                      : AppLocalizations.of(context)!.qualityAutoDescription,
                  selected: settings.openaiQuality,
                  enabled: settings.enabled,
                  choices: [
                    SettingsChoice(
                      value: 'standard',
                      label: AppLocalizations.of(context)!.effortAuto,
                    ),
                    SettingsChoice(
                      value: 'hd',
                      label: AppLocalizations.of(context)!.effortHigh,
                    ),
                  ],
                  valueLabel: settings.openaiQuality == 'hd'
                      ? AppLocalizations.of(context)!.effortHigh
                      : AppLocalizations.of(context)!.effortAuto,
                  showDivider: false,
                  onSelected: (value) {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setOpenaiQuality(value);
                  },
                ),
              ],
            ),

          // Test section
          SettingsSection(
            icon: Icons.play_arrow_outlined,
            title: AppLocalizations.of(context)!.test,
            children: [
              _ImageGenTestWidget(enabled: settings.enabled),
            ],
          ),

          SettingsSection(
            icon: Icons.info_outline,
            title: AppLocalizations.of(context)!.information,
            children: [
              SettingsListTile(
                icon: Icons.info_outline,
                title: AppLocalizations.of(context)!.aboutImageGeneration,
                subtitle: AppLocalizations.of(context)!
                    .aboutImageGenerationDescription,
              ),
              SettingsListTile(
                icon: Icons.terminal,
                title: AppLocalizations.of(context)!.imagineCommand,
                subtitle: AppLocalizations.of(context)!.imagineCommandUsage,
                showDivider: settings.provider == ImageGenProvider.automatic1111 ||
                    settings.provider == ImageGenProvider.openai ||
                    settings.provider == ImageGenProvider.openaiChat,
              ),
              if (settings.provider == ImageGenProvider.automatic1111)
                SettingsListTile(
                  icon: Icons.computer,
                  title: AppLocalizations.of(context)!.stableDiffusion,
                  subtitle:
                      AppLocalizations.of(context)!.stableDiffusionDescription,
                  showDivider: false,
                ),
              if (settings.provider == ImageGenProvider.openai)
                SettingsListTile(
                  icon: Icons.cloud,
                  title: 'GPT-Image',
                  subtitle: AppLocalizations.of(context).gptImageApiDescription,
                  showDivider: false,
                ),
              if (settings.provider == ImageGenProvider.openaiChat)
                SettingsListTile(
                  icon: Icons.chat,
                  title: AppLocalizations.of(context).oaiCompatibleChat,
                  subtitle: AppLocalizations.of(context)
                      .oaiCompatibleChatDescription,
                  showDivider: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(
      BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final availableModels = ref.watch(availableModelsProvider);
    final fetchedState = ref.watch(fetchedModelsProvider);
    final supportsFetching = settings.provider.supportsFetchingModels;

    // Determine the current model value
    final currentModel = availableModels.contains(settings.model)
        ? settings.model
        : (availableModels.isNotEmpty
            ? availableModels.first
            : settings.provider.defaultModel);

    return ListTile(
      title: Text(AppLocalizations.of(context)!.model),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ImageGenProvider.getModelDisplayName(currentModel)),
          if (fetchedState.error != null)
            Text(
              AppLocalizations.of(context).errorFetchingModels,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (supportsFetching)
            ChromeIconButton(
              icon: fetchedState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              tooltip: AppLocalizations.of(context).refreshModels,
              onPressed: settings.enabled && !fetchedState.isLoading
                  ? () => ref.read(fetchedModelsProvider.notifier).fetchModels()
                  : null,
            ),
          DropdownButton<String>(
            value: availableModels.contains(currentModel) ? currentModel : null,
            hint: Text(currentModel),
            onChanged: settings.enabled
                ? (value) {
                    if (value != null) {
                      ref
                          .read(imageGenSettingsProvider.notifier)
                          .setModel(value);
                    }
                  }
                : null,
            items: availableModels.map((model) {
              return DropdownMenuItem(
                value: model,
                child: Text(
                  ImageGenProvider.getModelDisplayName(model),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final controller = TextEditingController(text: settings.apiKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.apiKey),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.apiKey,
            hintText: AppLocalizations.of(context)!.enterApiKey,
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(imageGenSettingsProvider.notifier)
                  .setApiKey(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  void _showEndpointDialog(
      BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final controller = TextEditingController(text: settings.apiEndpoint);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.apiEndpoint),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.apiEndpointUrl,
            hintText: _getEndpointHint(settings.provider),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(imageGenSettingsProvider.notifier)
                  .setApiEndpoint(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  String _getEndpointHint(ImageGenProvider provider) {
    // Just return the provider's default endpoint
    return provider.defaultEndpoint;
  }
}

/// Widget for testing image generation
class _ImageGenTestWidget extends ConsumerStatefulWidget {
  final bool enabled;

  const _ImageGenTestWidget({required this.enabled});

  @override
  ConsumerState<_ImageGenTestWidget> createState() =>
      _ImageGenTestWidgetState();
}

class _ImageGenTestWidgetState extends ConsumerState<_ImageGenTestWidget> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(imageGenStateProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.prompt,
              hintText: AppLocalizations.of(context)!.enterPromptToGenerate,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: widget.enabled && !genState.isGenerating,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.enabled &&
                    _controller.text.isNotEmpty &&
                    !genState.isGenerating
                ? () {
                    final settings = ref.read(imageGenSettingsProvider);
                    ref.read(imageGenStateProvider.notifier).generate(
                          ImageGenRequest(
                            prompt: _controller.text,
                            negativePrompt: settings.defaultNegativePrompt,
                            width: settings.defaultWidth,
                            height: settings.defaultHeight,
                            steps: settings.defaultSteps,
                            cfgScale: settings.defaultCfgScale,
                            sampler: settings.defaultSampler,
                          ),
                        );
                  }
                : null,
            icon: genState.isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image),
            label: Text(genState.isGenerating
                ? AppLocalizations.of(context)!.generating
                : AppLocalizations.of(context)!.generate),
          ),

          // Progress bar
          if (genState.isGenerating) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: genState.progress),
            const SizedBox(height: 8),
            Text(
              '${(genState.progress * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],

          // Result
          if (genState.result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check,
                          size: 16, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.generationComplete,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)
                      .generatedPrompt(genState.result!.prompt)),
                  Text(
                    AppLocalizations.of(context)
                        .generatedSeed(genState.result!.seed.toString()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (genState.result!.images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)
                          .imagesGenerated(genState.result!.images.length),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Display generated images
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: genState.result!.images.length,
                        itemBuilder: (context, index) {
                          final imageData = genState.result!.images[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  _showFullScreenImage(context, imageData),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  imageData,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: AppTheme.darkCard,
                                      child: const Center(
                                        child: Icon(Icons.broken_image,
                                            color: AppTheme.textMuted),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Error
          if (genState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      genState.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, Uint8List imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dismiss on tap background
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.black87),
            ),
            // Image with zoom
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  imageData,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: ChromeIconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
