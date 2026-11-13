import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/screens/settings/image_gen_gallery_screen.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:native_tavern_qnn_upscale/native_tavern_qnn_upscale.dart';

/// Screen for image generation settings
class ImageGenSettingsScreen extends ConsumerWidget {
  const ImageGenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageGenSettingsProvider);
    // Keep Local QNN process synced with provider/model selection.
    ref.watch(localQnnLifecycleProvider);

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
                onChanged: (value) {
                  ref.read(imageGenSettingsProvider.notifier).setEnabled(value);
                },
              ),
              SettingsChoiceTile<ImageGenDisplayMode>(
                icon: Icons.view_agenda_outlined,
                title: AppLocalizations.of(context)!.imageGenDisplayMode,
                subtitle: AppLocalizations.of(context)!.imageGenDisplayModeHint,
                selected: settings.displayMode,
                enabled: settings.enabled,
                choices: [
                  SettingsChoice(
                    value: ImageGenDisplayMode.separateBubble,
                    label: AppLocalizations.of(context)!
                        .imageGenDisplayModeSeparate,
                    subtitle: AppLocalizations.of(context)!
                        .imageGenDisplayModeSeparateHint,
                  ),
                  SettingsChoice(
                    value: ImageGenDisplayMode.attach,
                    label:
                        AppLocalizations.of(context)!.imageGenDisplayModeAttach,
                    subtitle: AppLocalizations.of(context)!
                        .imageGenDisplayModeAttachHint,
                  ),
                ],
                valueLabel: settings.displayMode == ImageGenDisplayMode.attach
                    ? AppLocalizations.of(context)!.imageGenDisplayModeAttach
                    : AppLocalizations.of(context)!
                        .imageGenDisplayModeSeparate,
                onSelected: (value) {
                  ref
                      .read(imageGenSettingsProvider.notifier)
                      .setDisplayMode(value);
                },
              ),
              SettingsSwitchTile(
                icon: Icons.auto_awesome,
                title: AppLocalizations.of(context)!.imageGenAutoOnReply,
                subtitle: AppLocalizations.of(context)!.imageGenAutoOnReplyHint,
                value: settings.autoGenerateOnReply,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(imageGenSettingsProvider.notifier)
                            .setAutoGenerateOnReply(value);
                      }
                    : null,
              ),
              SettingsChoiceTile<int>(
                icon: Icons.filter_none_outlined,
                title: AppLocalizations.of(context)!.imageGenImagesPerReply,
                subtitle:
                    AppLocalizations.of(context)!.imageGenImagesPerReplyHint,
                selected: settings.imagesPerReply.clamp(1, 4),
                enabled: settings.enabled,
                showDivider: false,
                choices: [
                  for (var count = 1; count <= 4; count++)
                    SettingsChoice(
                      value: count,
                      label: '$count',
                    ),
                ],
                valueLabel: '${settings.imagesPerReply.clamp(1, 4)}',
                onSelected: (value) {
                  ref
                      .read(imageGenSettingsProvider.notifier)
                      .setImagesPerReply(value);
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
              if (!settings.provider.isOnDeviceQnn)
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
              if (!settings.provider.isOnDeviceQnn)
                _buildModelSelector(context, ref, settings),
              if (settings.provider.isOnDeviceQnn)
                _buildLocalQnnSection(context, ref, settings),
            ],
          ),

          const SizedBox(height: 16),

          // Default parameters
          SettingsSection(
            icon: Icons.settings_outlined,
            title: AppLocalizations.of(context)!.defaultParameters,
            children: [
              SettingsListTile(
                icon: Icons.aspect_ratio,
                title: AppLocalizations.of(context)!.imageSize,
                subtitle:
                    '${settings.defaultWidth} × ${settings.defaultHeight}',
                trailing: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                enabled: settings.enabled,
                onTap: settings.enabled
                    ? () => _showImageSizeDialog(context, ref, settings)
                    : null,
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
            title: AppLocalizations.of(context)!.scenePromptLayers,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: TextEditingController(
                    text: settings.commonPromptPrefix.isEmpty
                        ? settings.effectiveCommonPromptPrefix
                        : settings.commonPromptPrefix,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.qualityPrefix,
                    hintText: AppLocalizations.of(context)!.qualityPrefixHint('{prompt}'),
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
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.personaAppearanceTags,
                    hintText: AppLocalizations.of(context)!.personaAppearanceTagsHint,
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
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.aiTagInstruction,
                    hintText: AppLocalizations.of(context)!.aiTagInstructionHint,
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

          SettingsSection(
            icon: Icons.hd_outlined,
            title: AppLocalizations.of(context)!.imageUpscaleAfterGeneration,
            children: [
              SettingsSwitchTile(
                icon: Icons.photo_size_select_large_outlined,
                title: AppLocalizations.of(context)!.imageUpscaleAfterGeneration,
                subtitle:
                    AppLocalizations.of(context)!.imageUpscaleAfterGenerationHint,
                value: settings.upscaleEnabled,
                onChanged: settings.enabled
                    ? (value) {
                        ref
                            .read(imageGenSettingsProvider.notifier)
                            .setUpscaleEnabled(value);
                      }
                    : null,
              ),
              SettingsChoiceTile<int>(
                icon: Icons.zoom_out_map,
                title: AppLocalizations.of(context)!.imageUpscaleScale,
                selected: settings.upscaleScale,
                enabled: settings.enabled && settings.upscaleEnabled,
                choices: [
                  for (final scale in const [2, 3, 4])
                    SettingsChoice(
                      value: scale,
                      label: AppLocalizations.of(context)!
                          .imageUpscaleScaleValue(scale),
                    ),
                ],
                valueLabel: AppLocalizations.of(context)!
                    .imageUpscaleScaleValue(settings.upscaleScale),
                onSelected: (value) {
                  ref
                      .read(imageGenSettingsProvider.notifier)
                      .setUpscaleScale(value);
                },
                showDivider: false,
              ),
            ],
          ),

          SettingsSection(
            icon: Icons.photo_library_outlined,
            title: AppLocalizations.of(context)!.imageGenGallery,
            children: [
              SettingsListTile(
                icon: Icons.collections_outlined,
                title: AppLocalizations.of(context)!.imageGenGallery,
                subtitle: AppLocalizations.of(context)!.imageGenGalleryHint,
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                showDivider: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ImageGenGalleryScreen(),
                    ),
                  );
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
                showDivider: settings.provider == ImageGenProvider.automatic1111 ||
                    settings.provider == ImageGenProvider.openai ||
                    settings.provider == ImageGenProvider.openaiChat ||
                    settings.provider == ImageGenProvider.localQnn,
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

  Widget _buildLocalQnnSection(
    BuildContext context,
    WidgetRef ref,
    ImageGenSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final catalogAsync = ref.watch(localQnnCatalogProvider);
    final statusAsync = ref.watch(localQnnBackendStatusProvider);
    final status = statusAsync.asData?.value;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(Icons.memory, color: theme.colorScheme.primary),
          title: Text(l10n.localQnnModelStatus),
          subtitle: Text(_localQnnStatusLabel(l10n, status)),
        ),
        if (status != null &&
            (status.isLoading ||
                status.state == 'downloading' ||
                status.state == 'generating'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: status.progress,
                ),
                const SizedBox(height: 6),
                Text(
                  status.message ?? '',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          )
        else if (status?.isReady == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l10n.localQnnModelReady(
                status?.modelName ??
                    ImageGenProvider.getModelDisplayName(settings.model),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        catalogAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => ListTile(
            title: Text(l10n.localQnnUnavailable),
            subtitle: Text('$e'),
          ),
          data: (catalog) {
            if (catalog.isEmpty) {
              return ListTile(
                title: Text(l10n.localQnnUnavailable),
                subtitle: Text(l10n.localQnnOnlySnapdragonHint),
              );
            }
            return Column(
              children: [
                for (final model in catalog)
                  ListTile(
                    title: Text(model.name),
                    subtitle: Text(
                      model.downloaded
                          ? model.approximateSize
                          : '${model.approximateSize} · ${l10n.localQnnNotDownloaded}',
                    ),
                    selected: settings.model == model.id,
                    trailing: model.downloaded
                        ? Icon(
                            settings.model == model.id
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: settings.model == model.id
                                ? theme.colorScheme.primary
                                : null,
                          )
                        : (!model.custom
                            ? TextButton(
                                onPressed: settings.enabled
                                    ? () => _downloadLocalQnnModel(
                                          context,
                                          ref,
                                          model.id,
                                        )
                                    : null,
                                child: Text(l10n.localQnnDownloadModel),
                              )
                            : null),
                    onTap: settings.enabled && model.downloaded
                        ? () {
                            ref
                                .read(imageGenSettingsProvider.notifier)
                                .setModel(model.id);
                          }
                        : null,
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: settings.enabled
                  ? () => _importLocalQnnZip(context, ref)
                  : null,
              icon: const Icon(Icons.folder_zip_outlined),
              label: Text(l10n.localQnnImportZip),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '${l10n.localQnnImportZipHint}\n${l10n.localQnnOnlySnapdragonHint}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _localQnnStatusLabel(
    AppLocalizations l10n,
    LocalQnnBackendStatus? status,
  ) {
    if (status == null) return l10n.localQnnModelIdle;
    switch (status.state) {
      case 'ready':
        return l10n.localQnnModelReady(status.modelName ?? '');
      case 'starting':
      case 'loading':
        return l10n.localQnnModelLoading;
      case 'downloading':
        return l10n.localQnnModelDownloading;
      case 'stopping':
        return l10n.localQnnModelReleasing;
      case 'generating':
        return l10n.localQnnModelGenerating;
      case 'error':
        return status.message ?? l10n.localQnnUnavailable;
      default:
        return l10n.localQnnModelIdle;
    }
  }

  Future<void> _downloadLocalQnnModel(
    BuildContext context,
    WidgetRef ref,
    String modelId,
  ) async {
    final plugin = ref.read(localQnnPluginProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await plugin.downloadModel(modelId);
      ref.invalidate(localQnnCatalogProvider);
      ref.read(imageGenSettingsProvider.notifier).setModel(modelId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.localQnnDownloadComplete)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.localQnnDownloadFailed}: $e')),
      );
    }
  }

  Future<void> _importLocalQnnZip(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final plugin = ref.read(localQnnPluginProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null || path.isEmpty) return;

      // Match catalog by zip name when possible (e.g. AnythingV5_qnn2.28_*.zip).
      final imported = await plugin.importModelZip(zipPath: path);
      ref.invalidate(localQnnCatalogProvider);
      ref.read(imageGenSettingsProvider.notifier).setModel(imported.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.localQnnImportComplete)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.localQnnImportFailed}: $e')),
      );
    }
  }

  Widget _buildModelSelector(
      BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final availableModels = ref.watch(availableModelsProvider);
    final fetchedState = ref.watch(fetchedModelsProvider);
    final l10n = AppLocalizations.of(context)!;
    final currentModel = availableModels.contains(settings.model)
        ? settings.model
        : (availableModels.isNotEmpty
            ? availableModels.first
            : settings.provider.defaultModel);
    final displayName = currentModel.isEmpty
        ? l10n.notSet
        : ImageGenProvider.getModelDisplayName(currentModel);
    final subtitle = fetchedState.isLoading
        ? l10n.fetchingModels
        : (fetchedState.error != null
            ? l10n.errorFetchingModels
            : displayName);

    return SettingsListTile(
      icon: Icons.memory,
      title: l10n.model,
      subtitle: subtitle,
      maxSubtitleLines: 1,
      enabled: settings.enabled,
      trailing: fetchedState.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      onTap: !settings.enabled || fetchedState.isLoading
          ? null
          : () => _showImageModelPicker(
                context,
                ref,
                settings,
                availableModels,
                currentModel,
              ),
    );
  }

  void _showImageModelPicker(
    BuildContext context,
    WidgetRef ref,
    ImageGenSettings settings,
    List<String> availableModels,
    String currentModel,
  ) {
    if (availableModels.isNotEmpty) {
      _showImageModelListSheet(
        context,
        ref,
        availableModels,
        currentModel,
      );
      return;
    }
    _showImageModelManualDialog(context, ref, currentModel);
  }

  void _showImageModelListSheet(
    BuildContext context,
    WidgetRef ref,
    List<String> models,
    String selectedModel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return _ImageModelSelectionSheet(
              models: models,
              selectedModel: selectedModel,
              scrollController: scrollController,
              onModelSelected: (model) {
                ref.read(imageGenSettingsProvider.notifier).setModel(model);
                Navigator.pop(sheetContext);
              },
              onRefresh: () {
                Navigator.pop(sheetContext);
                ref.read(fetchedModelsProvider.notifier).fetchModels();
              },
              onManualEntry: () {
                Navigator.pop(sheetContext);
                _showImageModelManualDialog(context, ref, selectedModel);
              },
              title: l10n.selectModelCount(models.length),
              refreshTooltip: l10n.refreshModels,
              manualTooltip: l10n.enterManually,
              searchHint: l10n.searchModels,
            );
          },
        );
      },
    );
  }

  void _showImageModelManualDialog(
    BuildContext context,
    WidgetRef ref,
    String currentModel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentModel);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.enterModelName),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.modelName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(imageGenSettingsProvider.notifier)
                  .setModel(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showImageSizeDialog(
    BuildContext context,
    WidgetRef ref,
    ImageGenSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final widthController =
        TextEditingController(text: '${settings.defaultWidth}');
    final heightController =
        TextEditingController(text: '${settings.defaultHeight}');
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void applyPreset(ImageAspectRatio preset) {
              setDialogState(() {
                widthController.text = '${preset.width}';
                heightController.text = '${preset.height}';
                errorText = null;
              });
            }

            void save() {
              final width = int.tryParse(widthController.text.trim());
              final height = int.tryParse(heightController.text.trim());
              if (width == null ||
                  height == null ||
                  width < 256 ||
                  width > 2048 ||
                  height < 256 ||
                  height > 2048) {
                setDialogState(() => errorText = l10n.imageSizeInvalid);
                return;
              }
              ref.read(imageGenSettingsProvider.notifier).setDefaultSize(
                    width: width,
                    height: height,
                  );
              Navigator.pop(dialogContext);
            }

            return AlertDialog(
              title: Text(l10n.imageSize),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.imageSizeCustomHint,
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widthController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.imageSizeWidth,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (errorText != null) {
                                  setDialogState(() => errorText = null);
                                }
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('×'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.imageSizeHeight,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (errorText != null) {
                                  setDialogState(() => errorText = null);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n.imageSizeQuickPresets,
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in ImageAspectRatio.presets)
                            ActionChip(
                              label: Text(
                                '${preset.width}×${preset.height}',
                              ),
                              onPressed: () => applyPreset(preset),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: save,
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      widthController.dispose();
      heightController.dispose();
    });
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
  late final TextEditingController _controller;
  bool _hasText = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    final saved = ref.read(imageGenSettingsProvider).testPrompt;
    if (saved.isNotEmpty) {
      _controller.text = saved;
      _hasText = true;
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    final hasText = text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    ref.read(imageGenSettingsProvider.notifier).setTestPrompt(text);
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
                    _hasText &&
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

class _ImageModelSelectionSheet extends StatefulWidget {
  const _ImageModelSelectionSheet({
    required this.models,
    required this.selectedModel,
    required this.scrollController,
    required this.onModelSelected,
    required this.onRefresh,
    required this.onManualEntry,
    required this.title,
    required this.refreshTooltip,
    required this.manualTooltip,
    required this.searchHint,
  });

  final List<String> models;
  final String selectedModel;
  final ScrollController scrollController;
  final void Function(String model) onModelSelected;
  final VoidCallback onRefresh;
  final VoidCallback onManualEntry;
  final String title;
  final String refreshTooltip;
  final String manualTooltip;
  final String searchHint;

  @override
  State<_ImageModelSelectionSheet> createState() =>
      _ImageModelSelectionSheetState();
}

class _ImageModelSelectionSheetState extends State<_ImageModelSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _filteredModels;

  @override
  void initState() {
    super.initState();
    _filteredModels = widget.models;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredModels = widget.models;
      } else {
        _filteredModels = widget.models
            .where((model) {
              final id = model.toLowerCase();
              final label =
                  ImageGenProvider.getModelDisplayName(model).toLowerCase();
              return id.contains(query) || label.contains(query);
            })
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ChromeIconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: widget.refreshTooltip,
                  onPressed: widget.onRefresh,
                ),
                ChromeIconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: widget.manualTooltip,
                  onPressed: widget.onManualEntry,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? ChromeIconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: _filteredModels.length,
              itemBuilder: (context, index) {
                final model = _filteredModels[index];
                final selected = model == widget.selectedModel;
                return ListTile(
                  title: Text(ImageGenProvider.getModelDisplayName(model)),
                  subtitle: Text(model),
                  selected: selected,
                  trailing: selected
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () => widget.onModelSelected(model),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
