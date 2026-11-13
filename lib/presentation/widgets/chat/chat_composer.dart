import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/chat_background.dart';
import 'package:native_tavern/domain/services/markdown_hotkey_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/background_providers.dart';
import 'package:native_tavern/presentation/providers/chat_choice_providers.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/providers/quick_reply_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/providers/status_block_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_choice_panel.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_image_gen_panel.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_voice_input_button.dart';
import 'package:native_tavern/presentation/widgets/chat/context_usage_indicator.dart';
import 'package:native_tavern/presentation/widgets/chat/markdown_input_field.dart';
import 'package:native_tavern/presentation/widgets/chat/model_thinking_drawer.dart';
import 'package:native_tavern/presentation/widgets/chat/status_block_panel.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Chat input: draft field, attachments, and the option panels above it.
///
/// The page keeps the text controller, focus node, and scroll position, and
/// forwards a prepared message to the active chat.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.chatId,
    required this.controller,
    required this.focusNode,
    required this.chatState,
    required this.generatingImage,
    required this.ensureApiConfigured,
    required this.onSend,
    required this.onContinue,
    required this.onAfterSend,
    required this.onOpenImagine,
    required this.onGenerateImageForCurrentReply,
  });

  final String chatId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ActiveChatState chatState;
  final bool generatingImage;
  final bool Function() ensureApiConfigured;
  final Future<void> Function(
    String content,
    List<ChatAttachment> attachments,
  ) onSend;
  final VoidCallback onContinue;
  final VoidCallback onAfterSend;
  final Future<void> Function(ActiveChatState chatState) onOpenImagine;
  final VoidCallback onGenerateImageForCurrentReply;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  static const Object _composerOptionsTapGroup = Object();

  bool _showInputMenu = false;
  bool _showChoicePanel = false;
  bool _choicePanelPinned = false;
  bool _showStatusPanel = false;
  bool _statusPanelPinned = false;
  bool _showImageGenPanel = false;
  bool _imageGenPanelPinned = false;
  final List<ChatAttachment> _pendingAttachments = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) return;
    _pendingAttachments.clear();
    _showInputMenu = false;
    _showChoicePanel = false;
    _showStatusPanel = false;
    _showImageGenPanel = false;
  }

  @override
  Widget build(BuildContext context) => _buildInputArea(widget.chatState);

  Future<void> _sendCurrentDraft() async {
    final content = widget.controller.text.trim();
    final hasAttachments = _pendingAttachments.isNotEmpty;
    if (content.isEmpty && !hasAttachments) return;
    if (!widget.ensureApiConfigured()) return;

    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    widget.controller.clear();
    setState(_pendingAttachments.clear);
    widget.focusNode.unfocus();
    widget.onAfterSend();
    await widget.onSend(content, attachments);
  }

  void _setInputMenuVisible(bool visible) {
    if (_showInputMenu == visible) return;
    setState(() {
      _showInputMenu = visible;
      // Keep pinned auxiliary panels open while the input menu is shown.
      if (visible && !_choicePanelPinned) _showChoicePanel = false;
      if (visible && !_statusPanelPinned) _showStatusPanel = false;
      if (visible && !_imageGenPanelPinned) _showImageGenPanel = false;
    });
  }

  void _setChoicePanelVisible(bool visible) {
    if (_showChoicePanel == visible) return;
    setState(() {
      _showChoicePanel = visible;
      if (visible) {
        _showInputMenu = false;
        if (!_statusPanelPinned) _showStatusPanel = false;
        if (!_imageGenPanelPinned) _showImageGenPanel = false;
      }
    });
  }

  void _setStatusPanelVisible(bool visible) {
    if (_showStatusPanel == visible) return;
    setState(() {
      _showStatusPanel = visible;
      if (visible) {
        _showInputMenu = false;
        if (!_choicePanelPinned) _showChoicePanel = false;
        if (!_imageGenPanelPinned) _showImageGenPanel = false;
      }
    });
  }

  void _setImageGenPanelVisible(bool visible) {
    if (_showImageGenPanel == visible) return;
    setState(() {
      _showImageGenPanel = visible;
      if (visible) {
        _showInputMenu = false;
        if (!_choicePanelPinned) _showChoicePanel = false;
        if (!_statusPanelPinned) _showStatusPanel = false;
      }
    });
  }

  void _toggleChoicePanelPinned() {
    setState(() => _choicePanelPinned = !_choicePanelPinned);
  }

  void _toggleStatusPanelPinned() {
    setState(() => _statusPanelPinned = !_statusPanelPinned);
  }

  void _toggleImageGenPanelPinned() {
    setState(() => _imageGenPanelPinned = !_imageGenPanelPinned);
  }

  void _dismissComposerOptionPanels() {
    if (!_showInputMenu &&
        !_showChoicePanel &&
        !_showStatusPanel &&
        !_showImageGenPanel) {
      return;
    }
    setState(() {
      _showInputMenu = false;
      // Pinned panels survive tap-outside / focus loss.
      if (!_choicePanelPinned) {
        _showChoicePanel = false;
      }
      if (!_statusPanelPinned) {
        _showStatusPanel = false;
      }
      if (!_imageGenPanelPinned) {
        _showImageGenPanel = false;
      }
    });
  }

  Widget _composerOptionsTapTarget({required Widget child}) => TapRegion(
        groupId: _composerOptionsTapGroup,
        child: child,
      );

  Widget _composerOptionsDismissable({required Widget child}) => TapRegion(
        groupId: _composerOptionsTapGroup,
        onTapOutside: (_) => _dismissComposerOptionPanels(),
        child: child,
      );

  void _openReplyChoicesSettings() {
    _setChoicePanelVisible(false);
    context.openShell(AppRoutes.replyChoices);
  }

  void _openCharacterStatusSettings() {
    _setStatusPanelVisible(false);
    context.openShell(AppRoutes.characterStatus);
  }

  void _openImageGenSettings() {
    _setImageGenPanelVisible(false);
    context.openShell(AppRoutes.imageGenSettings);
  }

  Future<void> _refreshReplyChoices() async {
    final choiceConfig = ref.read(chatChoiceConfigProvider);
    if (!choiceConfig.enabled) return;

    final chatState = ref.read(activeChatProvider);
    if (chatState.isGenerating) return;
    if (chatState.messages.isEmpty ||
        chatState.messages.last.role != MessageRole.assistant) {
      _showSnackBar(AppLocalizations.of(context).replyChoicesEmpty);
      return;
    }

    final llmConfig = ref.read(llmConfigProvider);
    if (!widget.ensureApiConfigured()) return;

    final contextMessages =
        await ref.read(activeChatProvider.notifier).buildLlmContextForChoices();
    if (!mounted) return;
    await ref.read(chatChoiceSessionProvider.notifier).generateForChat(
          chatId: widget.chatId,
          config: llmConfig,
          contextMessages: contextMessages,
        );
  }

  Future<void> _refreshCharacterStatus() async {
    final statusConfig = ref.read(statusBlockConfigProvider);
    if (!statusConfig.enabled) return;

    final chatState = ref.read(activeChatProvider);
    if (chatState.isGenerating) return;
    if (chatState.messages.isEmpty ||
        chatState.messages.last.role != MessageRole.assistant) {
      _showSnackBar(AppLocalizations.of(context).characterStatusEmpty);
      return;
    }

    final llmConfig = ref.read(llmConfigProvider);
    if (!widget.ensureApiConfigured()) return;

    await ref
        .read(activeChatProvider.notifier)
        .refreshStatusBlockManually(llmConfig);
  }

  Future<void> _sendChoiceMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!widget.ensureApiConfigured()) return;

    widget.controller.clear();
    setState(_pendingAttachments.clear);
    widget.focusNode.unfocus();
    widget.onAfterSend();
    await widget.onSend(trimmed, const []);
  }

  void _onReplyChoicesButtonPressed() {
    _setChoicePanelVisible(!_showChoicePanel);
  }

  void _onCharacterStatusButtonPressed() {
    _setStatusPanelVisible(!_showStatusPanel);
  }

  void _onImageGenButtonPressed() {
    _setImageGenPanelVisible(!_showImageGenPanel);
  }

  void _showModelThinkingDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.appCornerRadius + 4),
        ),
      ),
      builder: (context) => const ModelThinkingDrawer(),
    );
  }

  void _focusMessageInputAtEnd() {
    final length = widget.controller.text.length;
    widget.controller.selection = TextSelection.collapsed(offset: length);
    widget.focusNode.requestFocus();
  }

  void _handleQuickReply(String message, bool autoSend) {
    if (!widget.ensureApiConfigured()) return;

    if (message.isEmpty) {
      widget.focusNode.unfocus();
      widget.onContinue();
      widget.onAfterSend();
    } else if (autoSend) {
      widget.focusNode.unfocus();
      unawaited(widget.onSend(message, const []));
      widget.onAfterSend();
    } else {
      widget.controller.text = message;
      _focusMessageInputAtEnd();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  bool _hasFloatingChatStage(
    ChatBackground background, {
    bool? live2dEnabled,
  }) {
    final live2d = live2dEnabled ??
        ref.read(activeChatProvider).character?.assets?.live2d?.enabled == true;
    return background.type != BackgroundType.none || live2d;
  }

  bool _hasFrostableChatStage(
    ChatBackground background, {
    bool? live2dEnabled,
  }) {
    final live2d = live2dEnabled ??
        ref.read(activeChatProvider).character?.assets?.live2d?.enabled == true;
    return background.type == BackgroundType.image || live2d;
  }

  /// Composer fill opacity when floating over a visual stage.
  double _composerShellOpacity(
    ChatBackground background, {
    bool? live2dEnabled,
  }) {
    if (!_hasFloatingChatStage(background, live2dEnabled: live2dEnabled)) {
      return 1.0;
    }
    return background.bubbleOpacity.clamp(0.0, 1.0);
  }

  double _composerFrostSigma(
    ChatBackground background, {
    bool? live2dEnabled,
  }) {
    if (!_hasFrostableChatStage(background, live2dEnabled: live2dEnabled)) {
      return 0;
    }
    return ref.watch(
      appSettingsProvider.select((s) => s.bubbleBlurSigma),
    );
  }

  Widget _buildInputArea(ActiveChatState chatState) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDesktop = !(Platform.isIOS || Platform.isAndroid);
    final background = ref
            .watch(
              effectiveBackgroundProvider(chatState.character?.id),
            )
            .valueOrNull ??
        ChatBackground.none;
    final composerOpacity = _composerShellOpacity(background);
    final composerFrostSigma = _composerFrostSigma(background);

    return SafeArea(
      top: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _focusMessageInputAtEnd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_pendingAttachments.isNotEmpty) ...[
                _buildAttachmentsPreview(),
                const SizedBox(height: 8),
              ],
              if (_showImageGenPanel) ...[
                _composerOptionsDismissable(
                  child: _composerExpansionPanel(
                    opacity: composerOpacity,
                    frostSigma: composerFrostSigma,
                    child: ChatImageGenPanel(
                      onOpenSettings: _openImageGenSettings,
                      onGenerateForCurrentReply:
                          widget.onGenerateImageForCurrentReply,
                      isPinned: _imageGenPanelPinned,
                      onTogglePin: _toggleImageGenPanelPinned,
                      isGenerating: widget.generatingImage ||
                          ref.watch(imageGenStateProvider).isGenerating,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_showChoicePanel) ...[
                _composerOptionsDismissable(
                  child: _composerExpansionPanel(
                    opacity: composerOpacity,
                    frostSigma: composerFrostSigma,
                    child: ChatChoicePanel(
                      onSelectChoice: _sendChoiceMessage,
                      onOpenSettings: _openReplyChoicesSettings,
                      onRefresh: _refreshReplyChoices,
                      isPinned: _choicePanelPinned,
                      onTogglePin: _toggleChoicePanelPinned,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_showStatusPanel) ...[
                _composerOptionsDismissable(
                  child: _composerExpansionPanel(
                    opacity: composerOpacity,
                    frostSigma: composerFrostSigma,
                    child: StatusBlockPanel(
                      onOpenSettings: _openCharacterStatusSettings,
                      onRefresh: _refreshCharacterStatus,
                      isPinned: _statusPanelPinned,
                      onTogglePin: _toggleStatusPanelPinned,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_showInputMenu) ...[
                _composerOptionsDismissable(
                  child: _composerExpansionPanel(
                    opacity: composerOpacity,
                    frostSigma: composerFrostSigma,
                    child: _buildInputMenuPanel(
                      _inputMenuShowsQuickReplies(chatState),
                      chatState,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _focusMessageInputAtEnd,
                child: ZephyrChatChrome.maybeFrosted(
                  sigma: composerFrostSigma,
                  shape: ZephyrChatChrome.composerShape(),
                  child: DecoratedBox(
                    decoration: ZephyrChatChrome.composerShell(
                      context,
                      opacity: composerOpacity,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                          child: MarkdownInputField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            maxLines: 5,
                            minLines: 1,
                            hintText: l10n.typeMessage,
                            onSubmitted:
                                isDesktop ? (_) => _sendCurrentDraft() : null,
                            textInputAction: isDesktop
                                ? TextInputAction.send
                                : TextInputAction.newline,
                            showToolbar: false,
                            decoration:
                                ZephyrChatChrome.composerFieldDecoration(
                              context,
                              hintText: l10n.typeMessage,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth.isFinite
                                        ? constraints.maxWidth
                                        : 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _composerActionCluster(children: [
                                        _composerOptionsTapTarget(
                                          child: ChromeIconButton(
                                            density:
                                                ChromeIconButtonDensity.compact,
                                            onPressed: () =>
                                                _setInputMenuVisible(
                                              !_showInputMenu,
                                            ),
                                            tooltip: l10n.moreOptions,
                                            icon: Icon(
                                              _showInputMenu
                                                  ? Icons.close_rounded
                                                  : Icons.tune_rounded,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const ContextUsageComposerButton(),
                                        const SizedBox(width: 8),
                                        ChromeIconButton(
                                          density:
                                              ChromeIconButtonDensity.compact,
                                          onPressed: () {
                                            _dismissComposerOptionPanels();
                                            _showModelThinkingDrawer();
                                          },
                                          tooltip: l10n.selectModel,
                                          icon: const Icon(
                                            Icons.smart_toy_outlined,
                                            size: 22,
                                          ),
                                        ),
                                      ]),
                                      _composerActionCluster(
                                        children: [
                                          ChatVoiceInputButton(
                                            controller: widget.controller,
                                            onAutoSend: _sendCurrentDraft,
                                          ),
                                          _composerOptionsTapTarget(
                                            child: ChromeIconButton(
                                              density: ChromeIconButtonDensity
                                                  .compact,
                                              onPressed:
                                                  _onImageGenButtonPressed,
                                              tooltip: l10n.showImageGenPanel,
                                              isSelected: _showImageGenPanel,
                                              icon: Icon(
                                                Icons.image_outlined,
                                                size: 22,
                                                color: ref
                                                        .watch(
                                                            imageGenSettingsProvider)
                                                        .enabled
                                                    ? null
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.38),
                                              ),
                                            ),
                                          ),
                                          _composerOptionsTapTarget(
                                            child: ChromeIconButton(
                                              density: ChromeIconButtonDensity
                                                  .compact,
                                              onPressed:
                                                  _onReplyChoicesButtonPressed,
                                              tooltip: l10n.showReplyChoices,
                                              isSelected: _showChoicePanel,
                                              icon: Icon(
                                                Icons.alt_route_outlined,
                                                size: 22,
                                                color: ref
                                                        .watch(
                                                            chatChoiceConfigProvider)
                                                        .enabled
                                                    ? null
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.38),
                                              ),
                                            ),
                                          ),
                                          _composerOptionsTapTarget(
                                            child: ChromeIconButton(
                                              density: ChromeIconButtonDensity
                                                  .compact,
                                              onPressed:
                                                  _onCharacterStatusButtonPressed,
                                              tooltip: l10n.showCharacterStatus,
                                              isSelected: _showStatusPanel,
                                              icon: Icon(
                                                Icons.badge_outlined,
                                                size: 22,
                                                color: ref
                                                        .watch(
                                                            statusBlockConfigProvider)
                                                        .enabled
                                                    ? null
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.38),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Tooltip(
                                            message: chatState.isGenerating
                                                ? l10n.stopGenerating
                                                : l10n.send,
                                            child: Material(
                                              color: scheme.primary,
                                              shape: const CircleBorder(),
                                              clipBehavior: Clip.antiAlias,
                                              child: InkWell(
                                                onTap: chatState.isGenerating
                                                    ? () => ref
                                                        .read(activeChatProvider
                                                            .notifier)
                                                        .cancelGeneration()
                                                    : _sendCurrentDraft,
                                                child: SizedBox(
                                                  width: 34,
                                                  height: 34,
                                                  child: Center(
                                                    child: chatState
                                                            .isGenerating
                                                        ? DecoratedBox(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: scheme
                                                                  .onPrimary,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2.5),
                                                            ),
                                                            child:
                                                                const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                            ),
                                                          )
                                                        : Icon(
                                                            Icons.send_rounded,
                                                            size: 18,
                                                            color: scheme
                                                                .onPrimary,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composerActionCluster({required List<Widget> children}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _composerExpansionPanel({
    required Widget child,
    double opacity = 1.0,
    double frostSigma = 0,
  }) {
    return ZephyrChatChrome.maybeFrosted(
      sigma: frostSigma,
      shape: ZephyrChatChrome.composerShape(),
      child: DecoratedBox(
        decoration: ZephyrChatChrome.composerShell(
          context,
          opacity: opacity,
        ),
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  bool _inputMenuShowsQuickReplies(ActiveChatState chatState) {
    final quickReplyConfig = ref.watch(quickReplyConfigProvider);
    final enabledReplies = ref.watch(enabledQuickRepliesProvider);
    return quickReplyConfig.showQuickReplies &&
        enabledReplies.isNotEmpty &&
        !chatState.isGenerating;
  }

  /// Build the expandable menu panel above the input field
  Widget _buildInputMenuPanel(
    bool showQuickReplies,
    ActiveChatState chatState,
  ) {
    return Padding(
      key: const ValueKey('chat-input-menu-panel'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InputMenuButton(
                      icon: Icons.image,
                      label: AppLocalizations.of(context).attachImage,
                      onTap: () {
                        _showAttachmentOptions();
                        _setInputMenuVisible(false);
                      },
                    ),
                    _InputMenuButton(
                      icon: Icons.text_format,
                      label: AppLocalizations.of(context).formatting,
                      onTap: () => _showFormattingMenu(),
                    ),
                    if (ref.watch(imageGenSettingsProvider).enabled)
                      _InputMenuButton(
                        key: const Key('chat-input-imagine'),
                        icon: Icons.auto_awesome,
                        label: AppLocalizations.of(context).imagine,
                        onTap: () {
                          _setInputMenuVisible(false);
                          widget.onOpenImagine(chatState);
                        },
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _inputMenuPlainIconChip(
                    tooltip:
                        AppLocalizations.of(context).appearanceSectionTitle,
                    icon: Icons.palette_outlined,
                    onTap: () {
                      _setInputMenuVisible(false);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          context.push(AppRoutes.appearancePush);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: ChromeControls.appBarActionGap),
                  _inputMenuPlainIconChip(
                    tooltip: AppLocalizations.of(context).settings,
                    icon: Icons.settings_outlined,
                    onTap: () {
                      _setInputMenuVisible(false);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          context.push(AppRoutes.settingsPush);
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          // Row 2: Quick replies (if enabled)
          if (showQuickReplies) ...[
            const SizedBox(height: 12),
            _buildQuickRepliesInMenu(),
          ],
        ],
      ),
    );
  }

  Widget _inputMenuPlainIconChip({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: ZephyrChatChrome.tappableMenuChip(
        context,
        showBorder: false,
        onTap: onTap,
        child: Icon(
          icon,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Build quick replies inside the menu panel
  Widget _buildQuickRepliesInMenu() {
    final enabledReplies = ref.watch(enabledQuickRepliesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: enabledReplies
          .map(
            (reply) => ZephyrChatChrome.tappableMenuChip(
              context,
              onTap: () {
                _handleQuickReply(reply.message, reply.autoSend);
                _setInputMenuVisible(false);
              },
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: Text(
                reply.label,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _showFormattingMenu() async {
    final l10n = AppLocalizations.of(context);
    final format = await showAdaptiveActionDrawer<MarkdownFormat>(
      context: context,
      title: l10n.formatting,
      actions: [
        _formattingDrawerItem(MarkdownFormat.bold, Icons.format_bold),
        _formattingDrawerItem(MarkdownFormat.italic, Icons.format_italic),
        _formattingDrawerItem(MarkdownFormat.underline, Icons.format_underline),
        _formattingDrawerItem(
          MarkdownFormat.strikethrough,
          Icons.strikethrough_s,
        ),
        _formattingDrawerItem(
          MarkdownFormat.inlineCode,
          Icons.code,
          showDividerAbove: true,
        ),
        _formattingDrawerItem(
          MarkdownFormat.codeBlock,
          Icons.integration_instructions,
        ),
        _formattingDrawerItem(
          MarkdownFormat.link,
          Icons.link,
          showDividerAbove: true,
        ),
        _formattingDrawerItem(MarkdownFormat.quote, Icons.format_quote),
        _formattingDrawerItem(
          MarkdownFormat.bulletList,
          Icons.format_list_bulleted,
          showDividerAbove: true,
        ),
        _formattingDrawerItem(
          MarkdownFormat.numberedList,
          Icons.format_list_numbered,
        ),
      ],
    );
    if (format != null && mounted) {
      _applyMarkdownFormat(format);
    }
  }

  AdaptiveActionDrawerItem<MarkdownFormat> _formattingDrawerItem(
    MarkdownFormat format,
    IconData icon, {
    bool showDividerAbove = false,
  }) {
    return AdaptiveActionDrawerItem(
      value: format,
      title: Text(format.displayName),
      leading: Icon(icon),
      showDividerAbove: showDividerAbove,
    );
  }

  /// Apply markdown formatting to the input field
  void _applyMarkdownFormat(MarkdownFormat format) {
    var currentValue = widget.controller.value;
    if (!currentValue.selection.isValid) {
      currentValue = currentValue.copyWith(
        selection: TextSelection.collapsed(offset: currentValue.text.length),
      );
      widget.controller.value = currentValue;
    }

    final newValue = MarkdownHotkeyService.applyFormat(
      value: currentValue,
      format: format,
    );
    widget.controller.value = newValue;
    widget.focusNode.requestFocus();
  }

  /// Build preview of pending attachments
  Widget _buildAttachmentsPreview() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        itemBuilder: (context, index) {
          final attachment = _pendingAttachments[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(attachment.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: AppTheme.darkCard,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeAttachment(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Check if running on desktop platform
  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Show attachment options (camera or gallery/files)
  void _showAttachmentOptions() {
    debugPrint('📎 _showAttachmentOptions called, isDesktop: $_isDesktop');

    // On desktop, directly open file picker
    if (_isDesktop) {
      debugPrint('📎 Opening file picker for desktop...');
      _pickImageFromFiles();
      return;
    }

    final l10n = AppLocalizations.of(context);
    // On mobile, show options sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.primaryColor,
              ),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppTheme.accentColor,
              ),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pick image from files using FilePicker (for desktop)
  Future<void> _pickImageFromFiles() async {
    final l10n = AppLocalizations.of(context);
    debugPrint('📎 _pickImageFromFiles called');
    try {
      debugPrint('📎 Calling FilePicker.platform.pickFiles...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        dialogTitle: l10n.selectImages,
      );

      debugPrint('📎 FilePicker result: $result');

      if (result != null && result.files.isNotEmpty) {
        debugPrint('📎 Got ${result.files.length} files');
        for (final file in result.files) {
          debugPrint('📎 File: ${file.name}, path: ${file.path}');
          if (file.path != null) {
            await _addAttachmentFromPath(file.path!);
          }
        }
      } else {
        debugPrint('📎 No files selected or result is null');
      }
    } catch (e, stackTrace) {
      final l10n = AppLocalizations.of(context);
      debugPrint('📎 FilePicker error: $e');
      debugPrint('📎 Stack trace: $stackTrace');
      _showSnackBar(l10n.failedToPickImage(e.toString()));
    }
  }

  /// Pick image from gallery (for mobile)
  Future<void> _pickImageFromGallery() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      for (final image in images) {
        await _addAttachmentFromXFile(image);
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToPickImage(e.toString()));
    }
  }

  /// Take photo with camera (for mobile)
  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        await _addAttachmentFromXFile(image);
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToTakePhoto(e.toString()));
    }
  }

  /// Add an attachment from a file path
  Future<void> _addAttachmentFromPath(String filePath) async {
    try {
      // Copy file to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory(
        p.join(appDir.path, 'NativeTavern', 'attachments'),
      );
      await attachmentsDir.create(recursive: true);

      final uuid = const Uuid();
      final extension = p.extension(filePath);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(attachmentsDir.path, newFileName);

      // Copy file
      final sourceFile = File(filePath);
      await sourceFile.copy(newPath);

      // Get file info
      final fileInfo = await File(newPath).stat();

      final attachment = ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
      );

      setState(() {
        _pendingAttachments.add(attachment);
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToAddAttachment(e.toString()));
    }
  }

  /// Add an attachment from XFile (for mobile image_picker)
  Future<void> _addAttachmentFromXFile(XFile file) async {
    try {
      // Copy file to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory(
        p.join(appDir.path, 'NativeTavern', 'attachments'),
      );
      await attachmentsDir.create(recursive: true);

      final uuid = const Uuid();
      final extension = p.extension(file.path);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(attachmentsDir.path, newFileName);

      // Copy file
      final bytes = await file.readAsBytes();
      await File(newPath).writeAsBytes(bytes);

      // Get file info
      final fileInfo = await File(newPath).stat();

      final attachment = ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
      );

      setState(() {
        _pendingAttachments.add(attachment);
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToAddAttachment(e.toString()));
    }
  }

  /// Remove an attachment
  void _removeAttachment(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }
}

/// Button widget for the input menu panel
class _InputMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InputMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ZephyrChatChrome.tappableMenuChip(
      context,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
