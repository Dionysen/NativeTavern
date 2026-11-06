import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/chat_background.dart';
import 'package:native_tavern/data/models/live2d.dart';
import 'package:native_tavern/data/models/rpg/rpg.dart';
import 'package:native_tavern/data/repositories/group_repository.dart';
import 'package:native_tavern/core/flags/rpg_product_ui.dart';
import 'package:native_tavern/core/utils/share_utils.dart';
import 'package:native_tavern/domain/services/chat_export_service.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/domain/services/markdown_hotkey_service.dart';
import 'package:native_tavern/domain/services/rpg_scenario_package_service.dart';
import 'package:native_tavern/domain/services/slash_command_service.dart';
import 'package:native_tavern/domain/services/tts_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/controllers/chat_tts_autoplay_controller.dart';
import 'package:native_tavern/presentation/providers/bookmark_providers.dart';
import 'package:native_tavern/presentation/providers/background_providers.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/providers/chat_extension_providers.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/providers/quick_reply_providers.dart';
import 'package:native_tavern/presentation/providers/chat_choice_providers.dart';
import 'package:native_tavern/presentation/providers/rpg_chat_providers.dart';
import 'package:native_tavern/presentation/providers/regex_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/providers/story_providers.dart';
import 'package:native_tavern/presentation/providers/tts_providers.dart';
import 'package:native_tavern/presentation/providers/world_info_providers.dart';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
import 'package:native_tavern/presentation/widgets/chat/author_note_dialog.dart';
import 'package:native_tavern/presentation/widgets/chat/bookmark_dialog.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_tail_scroll.dart';
import 'package:native_tavern/presentation/widgets/chat/data_bank_citation_preview.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_background_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_voice_input_button.dart';
import 'package:native_tavern/presentation/widgets/chat/message_content_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/memory_context_usage_sheet.dart';
import 'package:native_tavern/presentation/widgets/chat/quick_reply_bar.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_choice_panel.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_scaffold.dart';
import 'package:native_tavern/presentation/widgets/play/ai_play_feature_gate.dart';
import 'package:native_tavern/presentation/widgets/chat/markdown_input_field.dart';
import 'package:native_tavern/presentation/widgets/chat/reasoning_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/slash_command_suggestions.dart';
import 'package:native_tavern/presentation/widgets/chat/context_usage_indicator.dart';
import 'package:native_tavern/presentation/providers/context_usage_providers.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/widgets/chat/image_generation_dialog.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/presentation/widgets/chat/visual_novel_message_view.dart';
import 'package:native_tavern/presentation/widgets/chat/tts_playback_controls.dart';
import 'package:native_tavern/presentation/widgets/chat/tool_activity_panel.dart';
import 'package:native_tavern/presentation/widgets/chat/sprite_display.dart';
import 'package:native_tavern/presentation/widgets/live2d/live2d_character_view.dart';
import 'package:native_tavern/presentation/widgets/live2d/live2d_stage_gestures.dart';
import 'package:native_tavern/presentation/widgets/rpg/rpg_game_panel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../widgets/chat/swipe_picker_sheet.dart';

/// Provider for chat export service
final chatExportServiceProvider = Provider<ChatExportService>((ref) {
  return ChatExportService();
});

/// Chat screen for conversations
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? initialMessageId;
  final String? initialDraft;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.initialMessageId,
    this.initialDraft,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static final Object _importRpg = Object();
  /// Soft pin / explicit follow threshold (Zephyr AI chat uses 72).
  static const double _followSlop = 72.0;
  /// Hide the jump chip once the viewport is this close to the tail.
  /// Larger than [_followSlop] so “already at the bottom” matches what users see.
  static const double _scrollToBottomButtonSlop = 160.0;
  /// Shared [TapRegion] group so option panels dismiss on outside tap,
  /// without treating their own toggle buttons as outside.
  static const Object _composerOptionsTapGroup = Object();
  final TextEditingController _messageController = TextEditingController();
  final ChatTailScrollController _scrollController = ChatTailScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showSlashSuggestions = false;
  bool _showInputMenu = false;
  bool _showChoicePanel = false;
  bool _choicePanelPinned = false;
  final List<ChatAttachment> _pendingAttachments = [];
  final ImagePicker _imagePicker = ImagePicker();
  final ChatTTSAutoPlayController _ttsAutoPlayController =
      ChatTTSAutoPlayController();
  final Live2DCharacterController _live2DController =
      Live2DCharacterController();
  late final TTSStopAction _stopTts;
  final Map<String, GlobalKey<_MessageBubbleState>> _messageKeys = {};
  bool _initialMessageJumpScheduled = false;
  String? _highlightedMessageId;

  /// Finger is dragging the list; blocks tail anchoring (Zephyr AI chat).
  bool _userInteractingWithScroll = false;

  /// True while [animateTo]/jumpTo] is driving the list (not a finger/wheel).
  bool _programmaticScroll = false;

  /// Show jump-to-latest chip when the bubble list is scrolled away from end.
  bool _showScrollToBottomButton = false;

  /// Armed only after the user scrolls toward newer messages. Scrolling up
  /// (or stopping after an up-scroll) keeps the jump chip hidden.
  bool _jumpToLatestArmed = false;

  /// Chat top bar visibility when [AppSettings.hideChatAppBarOnScroll] is on.
  bool _chatAppBarVisible = true;

  /// Accumulated user scroll delta for hide/show thresholding.
  double _appBarScrollAccumulator = 0;

  /// Bumped to cancel in-flight forced scroll-to-bottom passes.
  int _scrollToBottomGeneration = 0;

  /// Metrics captured before older messages are prepended so we can keep the
  /// same visual anchor after the list grows upward.
  double? _pendingOlderScrollPixels;
  double? _pendingOlderMaxExtent;

  @override
  void initState() {
    super.initState();
    _stopTts = ref.read(ttsStopProvider);
    // Match Zephyr: followTail only tracks interaction. Stick-to-end itself is
    // gated by distanceFromEnd <= 1 inside ChatTailScrollPosition.
    _scrollController.followTail = () => !_userInteractingWithScroll;
    _scrollController.addListener(_syncScrollToBottomButton);
    // Load chat and bookmarks when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeChatProvider.notifier).loadChat(widget.chatId);
      ref.read(bookmarkNotifierProvider.notifier).loadBookmarks(widget.chatId);
      ref.read(rpgChatProvider(widget.chatId).notifier).load();
      // Refresh context usage to ensure fresh calculation
      // This handles cases where world info was updated while not in chat
      refreshContextUsageProviders(ref);
      final draft = widget.initialDraft?.trim();
      if (draft != null && draft.isNotEmpty) {
        _messageController.text = draft;
      }
    });

    // Listen for text changes to show/hide slash command suggestions
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final shouldShow = text.startsWith('/') && !text.contains(' ');
    if (shouldShow != _showSlashSuggestions) {
      setState(() => _showSlashSuggestions = shouldShow);
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.initialMessageId != widget.initialMessageId) {
      _initialMessageJumpScheduled = false;
      _highlightedMessageId = null;
      _messageKeys.clear();
      _chatAppBarVisible = true;
      _appBarScrollAccumulator = 0;
    }
  }

  void _scheduleInitialMessageJump(List<ChatMessage> messages) {
    final targetId = widget.initialMessageId;
    if (_initialMessageJumpScheduled || targetId == null || messages.isEmpty) {
      return;
    }
    final actualIndex = messages.indexWhere(
      (message) => message.id == targetId,
    );
    if (actualIndex < 0) return;
    _initialMessageJumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final denominator = math.max(1, messages.length - 1);
      final estimatedOffset = _scrollController.position.maxScrollExtent *
          actualIndex /
          denominator;
      _scrollController.jumpTo(
        estimatedOffset.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
      );

      for (var attempt = 0; attempt < 4 && mounted; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final targetContext = _messageKeys[targetId]?.currentContext;
        if (targetContext == null || !targetContext.mounted) continue;
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        if (!mounted) return;
        setState(() => _highlightedMessageId = targetId);
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && _highlightedMessageId == targetId) {
            setState(() => _highlightedMessageId = null);
          }
        });
        return;
      }
    });
  }

  void _setInputMenuVisible(bool visible) {
    if (_showInputMenu == visible) return;
    setState(() {
      _showInputMenu = visible;
      // Keep a pinned reply-choice panel open while the input menu is shown.
      if (visible && !_choicePanelPinned) _showChoicePanel = false;
    });
  }

  void _setChoicePanelVisible(bool visible) {
    if (_showChoicePanel == visible) return;
    setState(() {
      _showChoicePanel = visible;
      if (visible) _showInputMenu = false;
    });
  }

  void _toggleChoicePanelPinned() {
    setState(() => _choicePanelPinned = !_choicePanelPinned);
  }

  void _dismissComposerOptionPanels() {
    if (!_showInputMenu && !_showChoicePanel && !_showSlashSuggestions) {
      return;
    }
    setState(() {
      _showInputMenu = false;
      // Pinned choice panel survives tap-outside / focus loss.
      if (!_choicePanelPinned) {
        _showChoicePanel = false;
      }
      _showSlashSuggestions = false;
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
    context.push(AppRoutes.replyChoices);
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
    if (!_isApiConfigured(llmConfig)) {
      _showApiConfigurationDialog();
      return;
    }

    final contextMessages =
        await ref.read(activeChatProvider.notifier).buildLlmContextForChoices();
    if (!mounted) return;
    await ref.read(chatChoiceSessionProvider.notifier).generateForChat(
          chatId: widget.chatId,
          config: llmConfig,
          contextMessages: contextMessages,
        );
  }

  Future<void> _sendChoiceMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.startsWith('/')) {
      await _handleSlashCommand(trimmed);
      return;
    }

    final config = ref.read(llmConfigProvider);
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    _messageController.clear();
    setState(() {
      _showSlashSuggestions = false;
      _pendingAttachments.clear();
    });
    _focusNode.unfocus();
    _scrollToBottom(force: true);
    await ref.read(activeChatProvider.notifier).sendMessage(trimmed, config);
  }

  void _onReplyChoicesButtonPressed() {
    _setChoicePanelVisible(!_showChoicePanel);
  }

  Future<void> _saveLive2DTransform(
    String characterId,
    Live2DStageTransform transform,
  ) async {
    try {
      await ref.read(activeChatProvider.notifier).updateLive2DStageTransform(
            scale: transform.scale,
            offsetX: transform.offsetX,
            offsetY: transform.offsetY,
          );
      ref.invalidate(characterDetailProvider(characterId));
    } catch (error) {
      if (mounted) _showSnackBar(error.toString());
    }
  }

  @override
  void dispose() {
    unawaited(_stopTts(ownerId: widget.chatId));
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_syncScrollToBottomButton);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isNearListBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - _followSlop;
  }

  bool _canPinStreamTail({bool force = false}) {
    if (force) return true;
    if (_userInteractingWithScroll) return false;
    return _isNearListBottom();
  }

  void _handleListScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userInteractingWithScroll = true;
      _appBarScrollAccumulator = 0;
      // Cancel pending forced jump-to-end so a late post-frame pass cannot
      // yank the viewport after the user starts scrolling again.
      _scrollToBottomGeneration++;
    } else if (notification is UserScrollNotification) {
      final scrolling = notification.direction != ScrollDirection.idle;
      _userInteractingWithScroll = scrolling && !_programmaticScroll;
      // Cancel pending jump-to-end only for real user scrolls. Programmatic
      // animateTo also emits UserScrollNotification and must not cancel itself.
      if (scrolling && !_programmaticScroll) {
        _scrollToBottomGeneration++;
      }
    } else if (notification is ScrollEndNotification) {
      _userInteractingWithScroll = false;
      _programmaticScroll = false;
      _appBarScrollAccumulator = 0;
    }

    // Non-reverse list: positive delta / forward = toward newer (down).
    if (!_programmaticScroll) {
      if (notification is ScrollUpdateNotification) {
        final delta = notification.scrollDelta;
        if (delta != null) {
          if (delta > 0.5) {
            _jumpToLatestArmed = true;
          } else if (delta < -0.5) {
            _jumpToLatestArmed = false;
          }
        }
      } else if (notification is UserScrollNotification) {
        if (notification.direction == ScrollDirection.forward) {
          _jumpToLatestArmed = true;
        } else if (notification.direction == ScrollDirection.reverse) {
          _jumpToLatestArmed = false;
        }
      }
    }

    _updateChatAppBarVisibilityFromScroll(notification);
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification ||
        notification is UserScrollNotification) {
      _syncScrollToBottomButton();
    }
  }

  static const double _appBarHideScrollThreshold = 12;

  void _updateChatAppBarVisibilityFromScroll(ScrollNotification notification) {
    final hideOnScroll =
        ref.read(appSettingsProvider).hideChatAppBarOnScroll;
    if (!hideOnScroll) {
      if (!_chatAppBarVisible) {
        setState(() => _chatAppBarVisible = true);
      }
      return;
    }

    // Always reveal when the user reaches the top of the history.
    if (notification.metrics.pixels <= 0) {
      if (!_chatAppBarVisible) {
        setState(() => _chatAppBarVisible = true);
      }
      _appBarScrollAccumulator = 0;
      return;
    }

    if (notification is! ScrollUpdateNotification) return;
    final delta = notification.scrollDelta;
    if (delta == null || delta == 0) return;

    // Ignore programmatic jumps (send / regenerate / jump-to-latest).
    final userDriven =
        _userInteractingWithScroll || notification.dragDetails != null;
    if (!userDriven) return;

    _appBarScrollAccumulator += delta;
    if (_appBarScrollAccumulator > _appBarHideScrollThreshold &&
        _chatAppBarVisible) {
      setState(() => _chatAppBarVisible = false);
      _appBarScrollAccumulator = 0;
    } else if (_appBarScrollAccumulator < -_appBarHideScrollThreshold &&
        !_chatAppBarVisible) {
      setState(() => _chatAppBarVisible = true);
      _appBarScrollAccumulator = 0;
    }
  }

  void _syncScrollToBottomButton() {
    if (!mounted) return;
    if (_jumpToLatestArmed && !_isAwayFromListBottomForButton()) {
      _jumpToLatestArmed = false;
    }
    final shouldShow = _computeShowScrollToBottomButton();
    if (shouldShow == _showScrollToBottomButton) return;
    setState(() => _showScrollToBottomButton = shouldShow);
  }

  bool _isAwayFromListBottomForButton() {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return false;
    if (position.maxScrollExtent <= _scrollToBottomButtonSlop) return false;
    return position.extentAfter > _scrollToBottomButtonSlop;
  }

  bool _computeShowScrollToBottomButton() {
    // Only after a downward scroll (while moving or after stop), and only
    // while the viewport is still away from the newest messages.
    if (!_jumpToLatestArmed) return false;
    return _isAwayFromListBottomForButton();
  }

  /// Scroll to the newest messages (Zephyr `_scrollToEnd`).
  ///
  /// Pass [force] for user-initiated actions (send / import); otherwise only
  /// follows when the viewport is already near the bottom.
  /// Pass [soft] for the jump-to-latest chip — gentler ease, no hard snap.
  void _scrollToBottom({
    bool animate = true,
    bool force = false,
    bool soft = false,
  }) {
    final generation = ++_scrollToBottomGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollToBottomGeneration) return;
      _scrollToBottomNow(
        animate: animate,
        force: force,
        soft: soft,
        generation: generation,
      );
      // Soft chip scroll: one ease is enough; a follow-up jumpTo feels harsh.
      if (soft) return;
      // Second pass after layout settles (Zephyr does the same).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _scrollToBottomGeneration) return;
        _scrollToBottomNow(
          animate: false,
          force: force,
          generation: generation,
        );
        _syncScrollToBottomButton();
      });
    });
  }

  void _scrollToBottomImmediate({bool force = false}) {
    _scrollToBottom(animate: false, force: force);
  }

  void _scrollToBottomNow({
    required bool animate,
    bool force = false,
    bool soft = false,
    int? generation,
  }) {
    if (generation != null && generation != _scrollToBottomGeneration) return;
    if (!_canPinStreamTail(force: force)) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = position.maxScrollExtent;
    if (animate) {
      final distance = (target - position.pixels).abs();
      final duration = soft
          ? Duration(
              milliseconds: (320 + distance * 0.12).clamp(320, 520).round(),
            )
          : const Duration(milliseconds: 220);
      _programmaticScroll = true;
      unawaited(
        position.animateTo(
          target,
          duration: duration,
          curve: soft ? Curves.easeOut : Curves.easeOutCubic,
        ).whenComplete(() {
          _programmaticScroll = false;
          if (!mounted) return;
          if (generation != null && generation != _scrollToBottomGeneration) {
            return;
          }
          _syncScrollToBottomButton();
        }),
      );
      return;
    }
    if (position.pixels != target) {
      _programmaticScroll = true;
      position.jumpTo(target);
      _programmaticScroll = false;
    }
    _syncScrollToBottomButton();
  }

  void _preserveScrollAfterOlderMessagesLoaded() {
    final pixels = _pendingOlderScrollPixels;
    final oldMax = _pendingOlderMaxExtent;
    _pendingOlderScrollPixels = null;
    _pendingOlderMaxExtent = null;
    if (pixels == null || oldMax == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final delta = _scrollController.position.maxScrollExtent - oldMax;
      if (delta.abs() <= 0.5) return;
      _scrollController.jumpTo(
        (pixels + delta).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  /// Check if API is properly configured
  bool _isApiConfigured(LLMConfig config) {
    // Local providers (Ollama, KoboldCpp) don't need API key
    if (config.provider == LLMProvider.ollama ||
        config.provider == LLMProvider.koboldCpp) {
      return config.apiUrl.isNotEmpty;
    }
    // Cloud providers need API key
    return config.apiKey.isNotEmpty && config.apiUrl.isNotEmpty;
  }

  /// Show dialog to guide user to configure API
  void _showApiConfigurationDialog() {
    final parentContext = context;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(l10n.apiNotConfigured),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.apiNotConfiguredMessage),
            const SizedBox(height: 16),
            Text(
              l10n.supportedProviders,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('• ${l10n.claude} (Anthropic)'),
            Text('• ${l10n.openRouter}'),
            Text('• ${l10n.gemini} (Google)'),
            Text('• ${l10n.ollama} (${l10n.local})'),
            Text('• ${l10n.koboldCpp} (${l10n.local})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.later),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Use go instead of push because /ai-config is inside ShellRoute
              parentContext.go('/ai-config');
            },
            icon: const Icon(Icons.settings),
            label: Text(l10n.configureNow),
          ),
        ],
      ),
    );
  }

  /// Composer drawer: pick model, then reasoning effort.
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
      builder: (context) => const _ModelThinkingDrawer(),
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final hasAttachments = _pendingAttachments.isNotEmpty;

    // Allow sending if there's content OR attachments
    if (content.isEmpty && !hasAttachments) return;

    // Check if it's a slash command (only if no attachments)
    if (content.startsWith('/') && !hasAttachments) {
      await _handleSlashCommand(content);
      return;
    }

    final config = ref.read(llmConfigProvider);

    // Check if API is configured
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    // Capture attachments before clearing
    final attachments = List<ChatAttachment>.from(_pendingAttachments);

    _messageController.clear();
    setState(() {
      _showSlashSuggestions = false;
      _pendingAttachments.clear();
    });

    // Hide keyboard on mobile platforms
    _focusNode.unfocus();

    // Pin once when sending starts; do not force-jump after generation ends
    // (user may have scrolled up to read history during the stream).
    _scrollToBottom(force: true);
    await ref
        .read(activeChatProvider.notifier)
        .sendMessage(content, config, attachments: attachments);
  }

  Future<void> _toggleRpgMode() async {
    final controller = ref.read(rpgChatProvider(widget.chatId).notifier);
    final rpgState = ref.read(rpgChatProvider(widget.chatId));
    try {
      if (rpgState.enabled) {
        await controller.setEnabled(false);
      } else if (rpgState.hasSession) {
        await controller.setEnabled(true);
      } else {
        await _showRpgScenarioPicker();
      }
    } catch (error) {
      if (mounted) _showSnackBar(error.toString());
    }
  }

  Future<void> _showRpgScenarioPicker() async {
    final controller = ref.read(rpgChatProvider(widget.chatId).notifier);
    final scenarios = await controller.listScenarios();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).chooseRpgScenario,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ChromeIconButton(
                      onPressed: () => Navigator.pop(sheetContext, _importRpg),
                      icon: const Icon(Icons.file_open_outlined),
                      tooltip: AppLocalizations.of(context).importScenario,
                    ),
                  ],
                ),
              ),
              if (scenarios.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppLocalizations.of(context).noSavedScenarios,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: scenarios.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final scenario = scenarios[index];
                      return ListTile(
                        leading: const Icon(Icons.sports_esports_outlined),
                        title: Text(scenario.metadata.name),
                        subtitle: Text(
                          '${scenario.metadata.id} · ${scenario.metadata.version}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(sheetContext, scenario),
                      );
                    },
                  ),
                ),
              ListTile(
                key: const Key('rpg-import-scenario'),
                leading: const Icon(Icons.file_open_outlined),
                title:
                    Text(AppLocalizations.of(context).rpgImportScenarioPackage),
                onTap: () => Navigator.pop(sheetContext, _importRpg),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected is RpgScenario) {
      await controller.enable(selected);
    } else if (selected == _importRpg) {
      await _importRpgScenario();
    }
  }

  Future<void> _importRpgScenario() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: RpgScenarioPackageService.supportedExtensions,
      withData: true,
    );
    if (selection == null || selection.files.isEmpty) return;
    final file = selection.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw StateError(
        AppLocalizations.of(context).rpgSelectedScenarioUnreadable,
      );
    }
    final result = await const RpgScenarioPackageService().importBytesAsync(
      bytes,
      fileName: file.name,
    );
    if (!result.isValid) {
      throw StateError(
          result.issues.map((issue) => issue.toString()).join('\n'));
    }
    await ref
        .read(rpgChatProvider(widget.chatId).notifier)
        .enable(result.scenario!);
  }

  Future<void> _handleSlashCommand(String input) async {
    final slashService = ref.read(slashCommandServiceProvider);
    final result = slashService.parse(input);

    if (!result.isCommand) {
      // Not a command, send as regular message
      final config = ref.read(llmConfigProvider);
      if (!_isApiConfigured(config)) {
        _showApiConfigurationDialog();
        return;
      }
      _messageController.clear();
      setState(() => _showSlashSuggestions = false);

      // Hide keyboard on mobile platforms
      _focusNode.unfocus();

      _scrollToBottom(force: true);
      await ref.read(activeChatProvider.notifier).sendMessage(input, config);
      return;
    }

    if (result.error != null) {
      _showCommandError(result.error!);
      return;
    }

    final command = result.command!;
    final argument = result.argument;

    _messageController.clear();
    setState(() => _showSlashSuggestions = false);

    // Hide keyboard on mobile platforms
    _focusNode.unfocus();

    await _executeCommand(command, argument);
  }

  Future<void> _executeCommand(SlashCommand command, String? argument) async {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(llmConfigProvider);
    final chatNotifier = ref.read(activeChatProvider.notifier);
    final chatState = ref.read(activeChatProvider);

    switch (command.name) {
      case 'continue':
        if (!_isApiConfigured(config)) {
          _showApiConfigurationDialog();
          return;
        }
        _scrollToBottom(force: true);
        await chatNotifier.continueGeneration(config);
        break;

      case 'regenerate':
        if (!_isApiConfigured(config)) {
          _showApiConfigurationDialog();
          return;
        }
        _scrollToBottom(force: true);
        await chatNotifier.regenerateLastMessage(config);
        break;

      case 'swipe':
        _handleSwipeCommand(argument);
        break;

      case 'persona':
        context.go('/personas');
        break;

      case 'sys':
        if (argument != null && argument.isNotEmpty) {
          // Send as system/narrator message
          _showSystemMessage(argument);
        }
        break;

      case 'bg':
        context.push(AppRoutes.backgroundSettings);
        break;

      case 'impersonate':
        await _handleImpersonate();
        break;

      case 'imagine':
        await _handleImagineCommand(argument);
        break;

      case 'delswipe':
        if (chatState.messages.isNotEmpty) {
          final lastMessage = chatState.messages.last;
          if (lastMessage.swipes.length > 1) {
            await chatNotifier.deleteSwipe(
              lastMessage.id,
              lastMessage.currentSwipeIndex,
            );
            if (mounted) {
              _showSnackBar(AppLocalizations.of(context)!.swipeDeleted);
            }
          } else {
            _showSnackBar(AppLocalizations.of(context)!.noAlternateSwipes);
          }
        }
        break;

      case 'help':
        _showHelpDialog(argument);
        break;

      case 'clear':
        _showClearConfirmation();
        break;

      case 'edit':
        if (argument != null &&
            argument.isNotEmpty &&
            chatState.messages.isNotEmpty) {
          final lastMessage = chatState.messages.last;
          await chatNotifier.editMessage(lastMessage.id, argument);
        }
        break;

      case 'delete':
        if (chatState.messages.isNotEmpty) {
          final count = int.tryParse(argument ?? '1') ?? 1;
          for (var i = 0; i < count && chatState.messages.isNotEmpty; i++) {
            final lastMessage = ref.read(activeChatProvider).messages.last;
            await chatNotifier.deleteMessage(lastMessage.id);
          }
        }
        break;

      case 'bookmark':
        if (chatState.messages.isNotEmpty) {
          final lastMessage = chatState.messages.last;
          final lastIndex = chatState.messages.length - 1;
          _showCreateBookmarkDialog(lastMessage.id, lastIndex);
        }
        break;

      case 'note':
        if (argument != null && argument.isNotEmpty) {
          await chatNotifier.updateAuthorNoteSettings(
            chatId: widget.chatId,
            content: argument,
            enabled: true,
          );
          _showSnackBar(l10n.authorsNoteUpdated);
        } else {
          showAuthorNoteDialog(context, widget.chatId);
        }
        break;
    }
  }

  Future<void> _handleImagineCommand(String? argument) async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(imageGenSettingsProvider);
    if (!settings.enabled) {
      _showSnackBar('${l10n.imageGeneration}: ${l10n.configureNow}');
      return;
    }

    final request = ref.read(parseImagineCommandProvider)(
      '/imagine ${argument ?? ''}',
    );
    if (request == null) {
      _showCommandError(SlashCommands.imagine.usage);
      return;
    }

    _showSnackBar(l10n.imageGeneration);
    final result =
        await ref.read(imageGenStateProvider.notifier).generate(request);
    if (!mounted) return;
    if (result == null || result.images.isEmpty) {
      final error = ref.read(imageGenStateProvider).error;
      _showCommandError(error ?? l10n.noImageGenerated);
      return;
    }

    try {
      final attachments = await _saveGeneratedImages(result);
      await ref.read(activeChatProvider.notifier).addLocalMessage(
            role: MessageRole.user,
            content: request.prompt,
            attachments: attachments,
          );
      _showSnackBar('${l10n.generationComplete} (${attachments.length})');
      _scrollToBottom(force: true);
    } catch (error) {
      _showCommandError(l10n.failedToSaveImage('$error'));
    }
  }

  Future<List<ChatAttachment>> _saveGeneratedImages(
    ImageGenResult result,
  ) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'chat_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final attachments = <ChatAttachment>[];
    for (final imageBytes in result.images) {
      final imageId = const Uuid().v4();
      final fileName = '$imageId.${result.format}';
      final filePath = p.join(imagesDir.path, fileName);
      await File(filePath).writeAsBytes(imageBytes);
      attachments.add(
        ChatAttachment(
          id: imageId,
          path: filePath,
          mimeType: 'image/${result.format}',
          sizeBytes: imageBytes.length,
        ),
      );
    }
    return attachments;
  }

  void _handleSwipeCommand(String? argument) {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.read(activeChatProvider);
    if (chatState.messages.isEmpty) return;

    final lastMessage = chatState.messages.last;
    if (lastMessage.swipes.length <= 1) {
      _showSnackBar(l10n.noSwipesAvailable);
      return;
    }

    int newIndex = lastMessage.currentSwipeIndex;

    if (argument == null || argument.isEmpty || argument == 'right') {
      newIndex = (newIndex + 1) % lastMessage.swipes.length;
    } else if (argument == 'left') {
      newIndex = (newIndex - 1 + lastMessage.swipes.length) %
          lastMessage.swipes.length;
    } else {
      final parsed = int.tryParse(argument);
      if (parsed != null &&
          parsed >= 1 &&
          parsed <= lastMessage.swipes.length) {
        newIndex = parsed - 1;
      }
    }

    ref
        .read(activeChatProvider.notifier)
        .swipeMessage(lastMessage.id, newIndex);
  }

  void _showSystemMessage(String content) {
    final l10n = AppLocalizations.of(context);
    // For now, just show a snackbar. In the future, this could inject a system message
    _showSnackBar('${l10n.system}: $content');
  }

  void _showHelpDialog(String? commandName) {
    if (commandName != null && commandName.isNotEmpty) {
      final slashService = ref.read(slashCommandServiceProvider);
      final l10n = AppLocalizations.of(context);
      final help = slashService.getCommandHelp(commandName);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('/$commandName'),
          content: Text(help),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => const SlashCommandHelpDialog(),
      );
    }
  }

  void _showCommandError(String error) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.commandError),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  /// "Start Reply With" dialog: assistant prefill for this chat
  void _showStartReplyWithDialog() {
    final l10n = AppLocalizations.of(context)!;
    final chat = ref.read(activeChatProvider).chat;
    final controller = TextEditingController(text: chat?.startReplyWith ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.startReplyWith),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.startReplyWithHint),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(activeChatProvider.notifier)
                  .updateStartReplyWith(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  /// Impersonate: generate a user reply and put it in the input field
  Future<void> _handleImpersonate() async {
    final config = ref.read(llmConfigProvider);
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    final text =
        await ref.read(activeChatProvider.notifier).impersonate(config);
    if (!mounted) return;
    if (text != null) {
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: text.length,
      );
    }
  }

  /// Chat lorebooks: multi-select world books active only in this chat
  void _showChatLorebooksDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final worldInfosAsync = ref.watch(allWorldInfosProvider);
          final chat = ref.watch(activeChatProvider).chat;
          final linked = chat?.linkedWorldInfoIds ?? const <String>[];

          return AlertDialog(
            title: Text(l10n.chatLorebooks),
            content: SizedBox(
              width: double.maxFinite,
              child: worldInfosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (worldInfos) {
                  if (worldInfos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.chatLorebooksHint),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: worldInfos
                        .map(
                          (wi) => CheckboxListTile(
                            title: Text(wi.name),
                            subtitle: Text(
                              l10n.chatLorebooksHint,
                              style: const TextStyle(fontSize: 11),
                            ),
                            value: linked.contains(wi.id),
                            onChanged: (checked) {
                              final updated = List<String>.from(linked);
                              if (checked == true) {
                                updated.add(wi.id);
                              } else {
                                updated.remove(wi.id);
                              }
                              ref
                                  .read(activeChatProvider.notifier)
                                  .updateLinkedWorldBooks(updated);
                            },
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _onSlashCommandSelected(SlashCommand command) {
    // Fill in the command with a space for argument
    _messageController.text = '/${command.name} ';
    setState(() => _showSlashSuggestions = false);
    _focusMessageInputAtEnd();
  }

  void _focusMessageInputAtEnd() {
    final length = _messageController.text.length;
    _messageController.selection = TextSelection.collapsed(offset: length);
    _focusNode.requestFocus();
  }

  Future<void> _regenerateMessage() async {
    final config = ref.read(llmConfigProvider);

    // Check if API is configured
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    await ref.read(ttsStopProvider)(ownerId: widget.chatId);
    _scrollToBottom(force: true);
    await ref.read(activeChatProvider.notifier).regenerateLastMessage(config);
  }

  void _handleChatTTSChange(ActiveChatState? previous, ActiveChatState next) {
    if (!mounted) return;
    final action = _ttsAutoPlayController.evaluate(
      previous: previous,
      next: next,
      settings: ref.read(ttsSettingsProvider),
    );
    switch (action.kind) {
      case ChatTTSActionKind.none:
        return;
      case ChatTTSActionKind.stop:
        unawaited(ref.read(ttsStopProvider)(ownerId: widget.chatId));
      case ChatTTSActionKind.speak:
        unawaited(
          ref.read(ttsSpeakProvider)(
            action.text!,
            characterId: action.characterId,
            ownerId: widget.chatId,
            sourceId: action.sourceId,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(rpgChatExtensionsProvider);
    final chatState = ref.watch(activeChatProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final isConfigured = _isApiConfigured(llmConfig);

    // Scroll to bottom when new messages arrive or when chat finishes loading
    ref.listen(activeChatProvider, (previous, next) {
      if (!mounted) return;
      // Scroll to bottom when:
      // 1. New messages are added during conversation
      // 2. Chat finishes loading (transitions from loading to loaded with messages)
      final messageCountChanged =
          previous?.messages.length != next.messages.length;
      final olderMessagesLoaded = previous != null &&
          next.messages.length > previous.messages.length &&
          previous.messages.isNotEmpty &&
          next.messages.last.id == previous.messages.last.id &&
          next.messages.first.id != previous.messages.first.id;
      final loadingFinished = previous?.isLoading == true &&
          next.isLoading == false &&
          next.messages.isNotEmpty;

      if (olderMessagesLoaded) {
        _preserveScrollAfterOlderMessagesLoaded();
      } else if (loadingFinished) {
        _scrollToBottomImmediate(force: true);
      } else if (messageCountChanged) {
        // Soft pin: follow only when already near bottom / not dragging.
        _scrollToBottomImmediate();
      }
      _handleChatTTSChange(previous, next);
    });

    return PopScope(
      canPop: !chatState.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !chatState.hasUnsavedChanges) return;
        final shouldLeave = await _handleUnsavedLeave();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AdaptiveScaffold(
        appBar: _buildAppBar(chatState),
        appBarVisible: !ref.watch(
              appSettingsProvider.select((s) => s.hideChatAppBarOnScroll),
            ) ||
            _chatAppBarVisible,
        body: ChatBackgroundWidget(
          characterId: chatState.character?.id,
          child: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(builder: (context, constraints) {
            final contentWidth = math.min(constraints.maxWidth, 900.0);
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        // API not configured banner
                        if (!isConfigured) _buildApiConfigBanner(),

                        // Error banner
                        if (chatState.error != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.red.withValues(alpha: 0.2),
                            child: Row(
                              children: [
                                const Icon(Icons.error,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    chatState.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                ChromeIconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    // Clear error
                                  },
                                ),
                              ],
                            ),
                          ),

                        // Messages list
                        Expanded(
                          child: chatState.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildMessagesAreaWithScrollButton(chatState),
                        ),

                        if (kRpgProductUiEnabled)
                          RpgGamePanel(
                            chatId: widget.chatId,
                            onDisable: _toggleRpgMode,
                          ),

                        ToolActivityPanel(chatId: widget.chatId),

                        // Input area
                        _buildInputArea(chatState),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ),
    );
  }

  Widget _buildApiConfigBanner() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.apiNotConfigured,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  l10n.configureApiProvider,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            // Use go instead of push because /ai-config is inside ShellRoute
            onPressed: () => context.go('/ai-config'),
            child: Text(l10n.configure),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ActiveChatState chatState) {
    final l10n = AppLocalizations.of(context);
    final hasAuthorNote = chatState.chat?.authorNoteEnabled == true &&
        (chatState.chat?.authorNote.isNotEmpty ?? false);
    final rpgState = ref.watch(rpgChatProvider(widget.chatId));
    final hasStory = ref
            .watch(storyChaptersProvider(widget.chatId))
            .valueOrNull
            ?.isNotEmpty ==
        true;

    return AppBar(
      title: Text(
        chatState.group?.name ?? chatState.character?.name ?? l10n.chat,
        style: const TextStyle(fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: spacedAppBarActions([
        if (chatState.hasUnsavedChanges)
          ChromeIconButton(
            icon: Icon(
              Icons.save_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: l10n.saveChat,
            onPressed: _saveChatManually,
          ),
        ChatTTSPlaybackControls(ownerId: widget.chatId),
        if (kRpgProductUiEnabled)
          ChromeIconButton(
            key: const Key('rpg-mode-toggle'),
            icon: Icon(
              rpgState.enabled
                  ? Icons.sports_esports
                  : Icons.sports_esports_outlined,
              color: rpgState.enabled ? AppTheme.accentColor : null,
            ),
            tooltip:
                rpgState.enabled ? l10n.rpgDisableMode : l10n.rpgEnableMode,
            onPressed: rpgState.isLoading ? null : _toggleRpgMode,
          ),
        // Bookmarks button
        ChromeIconButton(
          icon: const Icon(Icons.bookmark_border),
          tooltip: l10n.bookmarks,
          onPressed: () => _showBookmarksDialog(context),
        ),
        // Live2D supplies a visual stage even when no image background is set.
        if (ref
                    .watch(effectiveBackgroundProvider(chatState.character?.id))
                    .valueOrNull
                    ?.type ==
                BackgroundType.image ||
            chatState.character?.assets?.live2d?.enabled == true)
          ChromeIconButton(
            icon: Icon(
              ref.watch(appSettingsProvider.select((s) => s.chatLayoutMode)) ==
                      'bubble'
                  ? Icons.auto_stories // Novel mode icon
                  : Icons.chat_bubble, // Bubble mode icon
            ),
            tooltip: l10n.switchLayout,
            onPressed: () {
              final currentMode = ref.read(appSettingsProvider).chatLayoutMode;
              final newMode =
                  currentMode == 'bubble' ? 'visualNovel' : 'bubble';
              ref
                  .read(appSettingsProvider.notifier)
                  .updateChatLayoutMode(newMode);
            },
          ),
        if (chatState.messages.isNotEmpty &&
            chatState.messages.last.role == MessageRole.assistant &&
            !chatState.isGenerating)
          ChromeIconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.regenerate,
            onPressed: _regenerateMessage,
          ),
        AdaptiveActionMenuButton<String>(
          itemBuilder: (context) => [
            AdaptiveActionDrawerItem(
              value: chatState.isGroupChat ? 'group' : 'character',
              leading: Icon(
                chatState.isGroupChat ? Icons.groups : Icons.person,
              ),
              title: Text(
                chatState.isGroupChat ? l10n.editGroup : l10n.viewCharacter,
              ),
            ),
            if (chatState.character != null)
              AdaptiveActionDrawerItem(
                value: 'live2d',
                leading: const Icon(Icons.animation),
                title: const Text('Live2D'),
              ),
            AdaptiveActionDrawerItem(
              value: 'new_chat',
              showDividerAbove: true,
              leading: const Icon(Icons.add_comment_outlined),
              title: Text(l10n.newChat),
            ),
            AdaptiveActionDrawerItem(
              value: 'author_note',
              showDividerAbove: true,
              leading: Icon(
                Icons.note_alt,
                color: hasAuthorNote ? AppTheme.accentColor : null,
              ),
              title: Text(l10n.authorsNote),
              subtitle: Text(
                hasAuthorNote ? l10n.enabled : l10n.disabled,
                style: TextStyle(
                  color: hasAuthorNote
                      ? AppTheme.accentColor
                      : AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            AdaptiveActionDrawerItem(
              value: 'start_reply_with',
              leading: Icon(
                Icons.format_quote,
                color: (ref
                            .read(activeChatProvider)
                            .chat
                            ?.startReplyWith
                            .isNotEmpty ??
                        false)
                    ? AppTheme.accentColor
                    : null,
              ),
              title: Text(l10n.startReplyWith),
            ),
            AdaptiveActionDrawerItem(
              value: 'impersonate',
              leading: const Icon(Icons.theater_comedy),
              title: Text(l10n.impersonate),
              subtitle: Text(
                l10n.impersonateHint,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            AdaptiveActionDrawerItem(
              value: 'moments_in_chat',
              leading: Icon(
                Icons.dynamic_feed_outlined,
                color: chatState.chat?.momentsInChat == true
                    ? AppTheme.accentColor
                    : null,
              ),
              title: Text(l10n.momentsInChat),
              subtitle: Text(
                chatState.chat?.momentsInChat == true
                    ? l10n.enabled
                    : l10n.disabled,
                style: TextStyle(
                  color: chatState.chat?.momentsInChat == true
                      ? AppTheme.accentColor
                      : AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            AdaptiveActionDrawerItem(
              value: 'chat_lorebooks',
              showDividerAbove: true,
              leading: Icon(
                Icons.public,
                color: (ref
                            .read(activeChatProvider)
                            .chat
                            ?.linkedWorldInfoIds
                            .isNotEmpty ??
                        false)
                    ? AppTheme.accentColor
                    : null,
              ),
              title: Text(l10n.chatLorebooks),
            ),
            AdaptiveActionDrawerItem(
              value: 'bookmarks',
              leading: const Icon(
                Icons.bookmark,
                color: AppTheme.accentColor,
              ),
              title: Text(l10n.bookmarks),
            ),
            if (hasStory)
              AdaptiveActionDrawerItem(
                value: 'story',
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(l10n.story),
              ),
            AdaptiveActionDrawerItem(
              value: 'memory_usage',
              leading: const Icon(Icons.psychology_outlined),
              title: Text(l10n.memoryUsed),
            ),
            if (chatState.hasUnsavedChanges)
              AdaptiveActionDrawerItem(
                value: 'save_chat',
                leading: Icon(
                  Icons.save_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(l10n.saveChat),
              ),
            AdaptiveActionDrawerItem(
              value: 'statistics',
              showDividerAbove: true,
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(l10n.chatStatistics),
            ),
            AdaptiveActionDrawerItem(
              value: 'export',
              leading: const Icon(Icons.upload),
              title: Text(l10n.exportChat),
              subtitle: Text(l10n.saveAsJsonl),
            ),
            AdaptiveActionDrawerItem(
              value: 'import',
              leading: const Icon(Icons.download),
              title: Text(l10n.importChat),
              subtitle: Text(l10n.chooseFile),
            ),
            AdaptiveActionDrawerItem(
              value: 'clear',
              leading: const Icon(Icons.delete_sweep),
              title: Text(l10n.clearMessages),
              destructive: true,
            ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'character':
                final characterId = chatState.character?.id;
                if (characterId != null) {
                  context.push('/characters/$characterId');
                }
                break;
              case 'statistics':
                context.push('/chat/${widget.chatId}/statistics');
                break;
              case 'group':
                final groupId = chatState.group?.id;
                if (groupId != null) {
                  context.push('/groups/$groupId');
                }
                break;
              case 'author_note':
                showAuthorNoteDialog(context, widget.chatId);
                break;
              case 'live2d':
                final characterId = chatState.character?.id;
                if (characterId != null) {
                  context.push('/characters/$characterId/live2d');
                }
                break;
              case 'new_chat':
                await _startNewChatWithSameCard();
                break;
              case 'start_reply_with':
                _showStartReplyWithDialog();
                break;
              case 'impersonate':
                _handleImpersonate();
                break;
              case 'moments_in_chat':
                unawaited(
                  ref.read(activeChatProvider.notifier).updateMomentsInChat(
                        chatState.chat?.momentsInChat != true,
                      ),
                );
                break;
              case 'chat_lorebooks':
                _showChatLorebooksDialog();
                break;
              case 'bookmarks':
                _showBookmarksDialog(context);
                break;
              case 'story':
                final enabled = await ensureAiPlayFeatureEnabled(
                  context,
                  ref,
                  AiPlayFeature.story,
                );
                if (enabled && mounted) {
                  context.push(
                    Uri(
                      path: AppRoutes.playStory,
                      queryParameters: {'chat': widget.chatId},
                    ).toString(),
                  );
                }
                break;
              case 'memory_usage':
                _showMemoryUsage();
                break;
              case 'save_chat':
                await _saveChatManually();
                break;
              case 'export':
                _showExportDialog();
                break;
              case 'import':
                _showImportDialog();
                break;
              case 'clear':
                _showClearConfirmation();
                break;
            }
          },
        ),
      ]),
    );
  }

  void _showMemoryUsage() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MemoryContextUsageSheet(chatId: widget.chatId),
    );
  }

  Widget _buildEmptyState(ActiveChatState chatState) {
    final l10n = AppLocalizations.of(context);
    final character = chatState.character;
    final group = chatState.group;

    Widget avatar;
    if (group != null) {
      avatar = const CircleAvatar(
        radius: 50,
        child: Icon(Icons.groups, size: 50),
      );
    } else if (character?.assets?.avatarPath != null) {
      avatar = CharacterAvatarCircle(
        imagePath: character!.assets!.avatarPath!,
        radius: 50,
        errorBuilder: (_, __, ___) => const CircleAvatar(
          radius: 50,
          child: Icon(Icons.person, size: 50),
        ),
      );
    } else {
      avatar = const CircleAvatar(
        radius: 50,
        child: Icon(Icons.person, size: 50),
      );
    }

    final characterId = character?.id;
    if (group == null && characterId != null && characterId.isNotEmpty) {
      avatar = Tooltip(
        message: l10n.viewCharacter,
        child: GestureDetector(
          onTap: () => context.push('/characters/$characterId'),
          child: avatar,
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(height: 16),
          Text(
            group?.name ?? character?.name ?? l10n.chat,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.startConversation,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesAreaWithScrollButton(ActiveChatState chatState) {
    final layoutMode = ref.watch(
      appSettingsProvider.select((s) => s.chatLayoutMode),
    );
    final area = _buildMessagesArea(chatState);
    final showButton =
        _showScrollToBottomButton && layoutMode != 'visualNovel';
    // Always keep the Stack so showing/hiding the chip does not rebuild the
    // message list out from under the scroll position.
    return Stack(
      fit: StackFit.expand,
      children: [
        area,
        if (showButton)
          Positioned(
            left: 0,
            right: 0,
            // Mid-lower of the message viewport, above the composer.
            bottom: 28,
            child: Center(child: _buildScrollToBottomButton()),
          ),
      ],
    );
  }

  Widget _buildScrollToBottomButton() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final characterId = ref.watch(activeChatProvider).character?.id;
    final background = ref
            .watch(effectiveBackgroundProvider(characterId))
            .valueOrNull ??
        ChatBackground.none;
    final opacity = _composerShellOpacity(background);
    final fill = ZephyrChatChrome.composerFill(scheme, theme.brightness);
    final color = opacity >= 1.0 ? fill : fill.withValues(alpha: opacity);
    return ZephyrChatChrome.withComposerShadow(
      context: context,
      opacity: opacity,
      child: Material(
        elevation: 0,
        color: color,
        shadowColor: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            _jumpToLatestArmed = false;
            if (_showScrollToBottomButton) {
              setState(() => _showScrollToBottomButton = false);
            }
            _scrollToBottom(animate: true, force: true, soft: true);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.scrollToBottom,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesArea(ActiveChatState chatState) {
    final layoutMode = ref.watch(
      appSettingsProvider.select((s) => s.chatLayoutMode),
    );
    final backgroundAsync = ref.watch(
      effectiveBackgroundProvider(chatState.character?.id),
    );
    final background = backgroundAsync.valueOrNull ?? ChatBackground.none;
    final hasBackground = background.type == BackgroundType.image;
    final hasLive2D = chatState.character?.assets?.live2d?.enabled == true;

    if (chatState.messages.isEmpty) {
      if (!hasLive2D) return _buildEmptyState(chatState);
      return Live2DBackgroundTapRegion(
        onTap: _handleLive2DBackgroundTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _buildLive2DStage(chatState, interactive: false),
              ),
            ),
            _buildEmptyState(chatState),
          ],
        ),
      );
    }

    if (widget.initialMessageId != null) {
      return _buildMessageList(chatState);
    }

    if (layoutMode == 'visualNovel' && (hasBackground || hasLive2D)) {
      return _buildVisualNovelView(chatState);
    }

    if (hasLive2D) {
      final character = chatState.character!;
      final live2d = character.assets!.live2d!;
      return Live2DTwoFingerGestureRegion(
        initialTransform: Live2DStageTransform.constrained(
          scale: live2d.scale,
          offsetX: live2d.offsetX,
          offsetY: live2d.offsetY,
        ),
        onTransformEnd: (transform) {
          unawaited(_saveLive2DTransform(character.id, transform));
        },
        builder: (context, transform) => Live2DBackgroundTapRegion(
          onTap: _handleLive2DBackgroundTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: _buildLive2DStage(
                    chatState,
                    configOverride: live2d.copyWith(
                      scale: transform.scale,
                      offsetX: transform.offsetX,
                      offsetY: transform.offsetY,
                    ),
                    interactive: false,
                    persistTransform: false,
                  ),
                ),
              ),
              _buildMessageList(chatState),
            ],
          ),
        ),
      );
    }

    return _buildMessageList(chatState);
  }

  Widget _buildVisualNovelView(ActiveChatState chatState) {
    final character = chatState.character;
    final live2d = character?.assets?.live2d;

    Widget buildContent(Live2DConfig? configOverride) {
      return Live2DBackgroundTapRegion(
        onTap: _handleLive2DBackgroundTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (live2d?.enabled == true)
              Positioned.fill(
                child: IgnorePointer(
                  child: _buildLive2DStage(
                    chatState,
                    configOverride: configOverride,
                    interactive: false,
                    persistTransform: false,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: VisualNovelMessageView(
                messages: chatState.messages,
                character: chatState.character,
                characterForMessage: chatState.characterForMessage,
                isGenerating: chatState.isGenerating,
                onLongPress: (message) => _showMessageOptionsForVisualNovel(
                  context,
                  message,
                  chatState,
                ),
                onSwipe: (swipeIndex, messageId) {
                  ref
                      .read(activeChatProvider.notifier)
                      .swipeMessage(messageId, swipeIndex);
                },
              ),
            ),
          ],
        ),
      );
    }

    if (character == null || live2d?.enabled != true) {
      return buildContent(null);
    }

    return Live2DTwoFingerGestureRegion(
      initialTransform: Live2DStageTransform.constrained(
        scale: live2d!.scale,
        offsetX: live2d.offsetX,
        offsetY: live2d.offsetY,
      ),
      onTransformEnd: (transform) {
        unawaited(_saveLive2DTransform(character.id, transform));
      },
      builder: (context, transform) => buildContent(
        live2d.copyWith(
          scale: transform.scale,
          offsetX: transform.offsetX,
          offsetY: transform.offsetY,
        ),
      ),
    );
  }

  void _handleLive2DBackgroundTap(Offset position) {
    unawaited(
      _live2DController.handleTapAt(position).then((played) {
        debugPrint(
          '[Live2D] Chat tap at $position: '
          'attached=${_live2DController.isAttached}, '
          'ready=${_live2DController.isReady}, played=$played',
        );
      }),
    );
  }

  Widget _buildLive2DStage(
    ActiveChatState chatState, {
    Live2DConfig? configOverride,
    bool interactive = true,
    bool persistTransform = true,
  }) {
    final character = chatState.character;
    final live2d = configOverride ?? character?.assets?.live2d;
    if (character == null || live2d?.enabled != true) {
      return const SizedBox.shrink();
    }

    ChatMessage? latestAssistantMessage;
    for (final message in chatState.messages.reversed) {
      if (message.role == MessageRole.assistant) {
        latestAssistantMessage = message;
        break;
      }
    }

    return Consumer(
      builder: (context, ttsRef, _) {
        final ttsEnabled = ttsRef.watch(
          ttsSettingsProvider.select((settings) => settings.enabled),
        );
        final playback = ttsRef.watch(ttsPlaybackStateProvider);
        final matchesStage = playback.ownerId == widget.chatId &&
            (playback.characterId == null ||
                playback.characterId == character.id);
        final stagePlayback = !ttsEnabled
            ? null
            : matchesStage
                ? playback
                : TTSPlaybackState(sequence: playback.sequence);

        return Live2DCharacterView(
          config: live2d!,
          controller: _live2DController,
          isSpeaking: chatState.isGenerating,
          responseText: latestAssistantMessage?.content ?? '',
          ttsPlayback: stagePlayback,
          interactive: interactive,
          resetOnDoubleTap: false,
          onTransformChanged: persistTransform
              ? (transform) {
                  unawaited(_saveLive2DTransform(character.id, transform));
                }
              : null,
          fallback: latestAssistantMessage == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.center,
                  child: SpriteDisplay(
                    characterId: character.id,
                    messageContent: latestAssistantMessage.content,
                    isStreaming: chatState.isGenerating,
                  ),
                ),
        );
      },
    );
  }

  void _showMessageOptionsForVisualNovel(
    BuildContext context,
    ChatMessage message,
    ActiveChatState chatState,
  ) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final config = ref.read(llmConfigProvider);
    final isAssistant = message.role == MessageRole.assistant;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.copy, color: scheme.onSurfaceVariant),
                title: Text(l10n.copy),
                onTap: () {
                  Navigator.pop(context);
                  final content = message.content;
                  if (content.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: content));
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: scheme.onSurfaceVariant),
                title: Text(l10n.edit),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMessageDialog(message);
                },
              ),
              if (isAssistant)
                ListTile(
                  leading:
                      Icon(Icons.volume_up_outlined, color: scheme.primary),
                  title: Text(l10n.readAloud),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      ref.read(ttsSpeakProvider)(
                        message.content,
                        characterId:
                            message.characterId ?? chatState.character?.id,
                        ownerId: widget.chatId,
                        sourceId: message.id,
                      ),
                    );
                  },
                ),
              if (isAssistant)
                ListTile(
                  leading: Icon(Icons.refresh, color: scheme.primary),
                  title: Text(l10n.regenerate),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(activeChatProvider.notifier)
                        .regenerateMessage(message.id, config);
                  },
                ),
              ListTile(
                leading: Icon(Icons.play_arrow, color: scheme.tertiary),
                title: Text(l10n.continueFromHere),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(activeChatProvider.notifier)
                      .continueFromMessage(message.id, config);
                },
              ),
              ListTile(
                leading: Icon(Icons.call_split, color: scheme.secondary),
                title: Text(l10n.newBranchChat),
                subtitle: Text(l10n.newBranchChatHint),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_branchChatFromMessage(message.id));
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: scheme.error),
                title: Text(
                  l10n.delete,
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(message.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(ActiveChatState chatState) {
    if (widget.initialMessageId != null &&
        !chatState.messages
            .any((message) => message.id == widget.initialMessageId) &&
        chatState.hasOlderMessages &&
        !chatState.isLoadingOlderMessages) {
      if (_scrollController.hasClients) {
        _pendingOlderScrollPixels = _scrollController.position.pixels;
        _pendingOlderMaxExtent = _scrollController.position.maxScrollExtent;
      }
      unawaited(ref.read(activeChatProvider.notifier).loadOlderMessages());
    }
    _scheduleInitialMessageJump(chatState.messages);
    final config = ref.read(llmConfigProvider);
    final backgroundAsync = ref.watch(
      effectiveBackgroundProvider(chatState.character?.id),
    );
    final background = backgroundAsync.valueOrNull ?? ChatBackground.none;
    final hasBackground = background.type != BackgroundType.none ||
        chatState.character?.assets?.live2d?.enabled == true;
    final hasImageBackground = background.type == BackgroundType.image;

    final showOlderLoader =
        chatState.hasOlderMessages || chatState.isLoadingOlderMessages;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleListScrollNotification(notification);
        if (notification.depth != 0 ||
            notification.metrics.axis != Axis.vertical ||
            !chatState.hasOlderMessages ||
            chatState.isLoadingOlderMessages) {
          return false;
        }
        // Non-reverse list: oldest messages / loader sit at the top.
        if (notification.metrics.pixels <= 160) {
          if (_scrollController.hasClients) {
            _pendingOlderScrollPixels = _scrollController.position.pixels;
            _pendingOlderMaxExtent =
                _scrollController.position.maxScrollExtent;
          }
          unawaited(
            ref.read(activeChatProvider.notifier).loadOlderMessages(),
          );
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        // Keep nearby HTML WebViews mounted a bit longer to cut recycle flash.
        cacheExtent: 1600,
        // Chronological list like Zephyr: newest at maxScrollExtent.
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: chatState.messages.length + (showOlderLoader ? 1 : 0),
        itemBuilder: (context, index) {
          if (showOlderLoader && index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: chatState.isLoadingOlderMessages
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          final actualIndex = showOlderLoader ? index - 1 : index;
          final message = chatState.messages[actualIndex];
          final isLast = actualIndex == chatState.messages.length - 1;

          final layoutMode = ref.watch(
            appSettingsProvider.select((s) => s.chatLayoutMode),
          );

          return _MessageBubble(
            key: _messageKeys.putIfAbsent(
              message.id,
              () => GlobalKey<_MessageBubbleState>(),
            ),
            message: message,
            messageIndex:
                actualIndex, // Use actual index for bookmarks and other features
            messageDepth: chatState.messages.length - 1 - actualIndex,
            chatId: widget.chatId,
            character: chatState.characterForMessage(message),
            isGenerating: chatState.generatingMessageIds.contains(message.id) ||
                (isLast &&
                    message.role == MessageRole.assistant &&
                    chatState.isGenerating &&
                    chatState.generatingMessageIds.isEmpty),
            isLast: isLast,
            hasBackground: hasBackground,
            hasImageBackground: hasImageBackground,
            bubbleOpacity: background.bubbleOpacity,
            layoutMode: layoutMode,
            highlighted: _highlightedMessageId == message.id,
            onSwipe: (swipeIndex) {
              ref
                  .read(activeChatProvider.notifier)
                  .swipeMessage(message.id, swipeIndex);
            },
            onDeleteSwipe: (swipeIndex) {
              return ref
                  .read(activeChatProvider.notifier)
                  .deleteSwipe(message.id, swipeIndex);
            },
            onEdit: (newContent) {
              ref
                  .read(activeChatProvider.notifier)
                  .editMessage(message.id, newContent);
            },
            onDelete: () {
              _showDeleteConfirmation(message.id);
            },
            onRegenerate: message.role == MessageRole.assistant
                ? () {
                    ref
                        .read(activeChatProvider.notifier)
                        .regenerateMessage(message.id, config);
                  }
                : null,
            onContinueFromHere: () {
              ref
                  .read(activeChatProvider.notifier)
                  .continueFromMessage(message.id, config);
            },
            onDeleteAndAfter: () {
              _showDeleteAndAfterConfirmation(message.id);
            },
            onCreateBookmark: () {
              _showCreateBookmarkDialog(message.id, actualIndex);
            },
            onBranchChat: () {
              unawaited(_branchChatFromMessage(message.id));
            },
            onGenerateImage: ref.read(imageGenSettingsProvider).enabled
                ? () {
                    _showImageGenerationDialog(message, chatState.character);
                  }
                : null,
          );
        },
      ),
    );
  }

  Future<void> _showEditMessageDialog(ChatMessage message) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: message.content);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.edit),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated != null) {
      await ref
          .read(activeChatProvider.notifier)
          .editMessage(message.id, updated);
    }
  }

  void _showBookmarksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BookmarksListDialog(chatId: widget.chatId),
    );
  }

  Future<void> _openImagineFromInput(ActiveChatState chatState) async {
    final typed = _messageController.text.trim();
    final lastAssistant =
        chatState.messages.reversed.cast<ChatMessage?>().firstWhere(
              (message) => message?.role == MessageRole.assistant,
              orElse: () => null,
            );
    final result = await ImageGenerationDialog.show(
      context,
      basePrompt: typed.isNotEmpty ? typed : (lastAssistant?.content ?? ''),
      characterName: chatState.character?.name,
      mode: ImageGenMode.free,
      autoCompose: typed.isEmpty,
    );
    if (result != null && result.images.isNotEmpty && mounted) {
      await _attachGeneratedImagesToNewMessage(result);
    }
  }

  Future<void> _attachGeneratedImagesToNewMessage(ImageGenResult result) async {
    final l10n = AppLocalizations.of(context);
    try {
      final attachments = await _saveGeneratedImages(result);
      await ref.read(activeChatProvider.notifier).addLocalMessage(
            role: MessageRole.user,
            content: result.prompt,
            attachments: attachments,
          );
      _showSnackBar('${l10n.generationComplete} (${attachments.length})');
      _scrollToBottom(force: true);
    } catch (error) {
      _showCommandError(l10n.failedToSaveImage('$error'));
    }
  }

  void _showImageGenerationDialog(
    ChatMessage message,
    Character? character,
  ) async {
    final result = await ImageGenerationDialog.show(
      context,
      basePrompt: message.content,
      characterName: character?.name,
      mode: message.role == MessageRole.assistant
          ? ImageGenMode.lastMessage
          : ImageGenMode.free,
      autoCompose: message.role == MessageRole.assistant,
    );

    if (result != null && result.images.isNotEmpty && mounted) {
      final l10n = AppLocalizations.of(context);

      // Save each image to local storage and add as attachment to the message
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDocDir.path, 'chat_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        for (int i = 0; i < result.images.length; i++) {
          final imageBytes = result.images[i];
          final imageId = const Uuid().v4();
          final fileName = '${imageId}.${result.format}';
          final filePath = p.join(imagesDir.path, fileName);

          // Save image to file
          final file = File(filePath);
          await file.writeAsBytes(imageBytes);

          // Create attachment
          final attachment = ChatAttachment(
            id: imageId,
            path: filePath,
            mimeType: 'image/${result.format}',
            sizeBytes: imageBytes.length,
          );

          // Add attachment to message
          await ref
              .read(activeChatProvider.notifier)
              .addAttachmentToMessage(message.id, attachment);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.imagesAdded(result.images.length),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Failed to save generated image: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(l10n.failedToSaveImage('$e'))),
        );
      }
    }
  }

  void _showCreateBookmarkDialog(String messageId, int messageIndex) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => CreateBookmarkDialog(
        chatId: widget.chatId,
        messageId: messageId,
        messageIndex: messageIndex,
      ),
    );

    if (result != null && mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookmarkCreated)));
    }
  }

  Future<void> _startNewChatWithSameCard() async {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.read(activeChatProvider);
    final chat = chatState.chat;
    final notifier = ref.read(activeChatProvider.notifier);

    final String? newChatId;
    final groupId = chat?.groupId;
    if (groupId != null) {
      final group = chatState.group ??
          await ref.read(groupRepositoryProvider).getGroup(groupId);
      if (group == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToCreateChat)),
        );
        return;
      }
      newChatId = await notifier.createGroupChat(group);
    } else {
      final characterId =
          chatState.character?.id ?? chat?.characterId;
      if (characterId == null || characterId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToCreateChat)),
        );
        return;
      }
      newChatId = await notifier.createChat(characterId);
    }

    if (!mounted) return;
    if (newChatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToCreateChat)),
      );
      return;
    }
    ref.invalidate(allChatsProvider);
    context.push('/chat/$newChatId');
  }

  Future<void> _branchChatFromMessage(String messageId) async {
    final l10n = AppLocalizations.of(context);
    final newChatId = await ref
        .read(activeChatProvider.notifier)
        .branchChatFromMessage(messageId);
    if (!mounted) return;
    if (newChatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.branchChatCreated)),
    );
    context.push('/chat/$newChatId');
  }

  Future<void> _showDeleteConfirmation(String messageId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deleteMessage,
      body: l10n.deleteMessageConfirmation,
    );
    if (!confirmed || !mounted) return;
    ref.read(activeChatProvider.notifier).deleteMessage(messageId);
  }

  Future<void> _showDeleteAndAfterConfirmation(String messageId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deleteMessages,
      body: l10n.deleteMessagesConfirmation,
      confirmLabel: l10n.deleteAll,
    );
    if (!confirmed || !mounted) return;
    ref.read(activeChatProvider.notifier).deleteMessageAndAfter(messageId);
  }

  Widget _buildQuickReplyBar(ActiveChatState chatState) {
    final quickReplyConfig = ref.watch(quickReplyConfigProvider);

    // Don't show if generating or if quick replies are disabled
    if (chatState.isGenerating || !quickReplyConfig.showQuickReplies) {
      return const SizedBox.shrink();
    }

    return QuickReplyBar(
      onQuickReply: (message, autoSend) => _handleQuickReply(message, autoSend),
    );
  }

  void _handleQuickReply(String message, bool autoSend) {
    final config = ref.read(llmConfigProvider);

    // Check if API is configured
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    if (message.isEmpty) {
      // Empty message means "continue" - just generate without user message
      _focusNode.unfocus(); // Hide keyboard
      ref.read(activeChatProvider.notifier).continueGeneration(config);
      _scrollToBottom(force: true);
    } else if (autoSend) {
      // Auto-send: send the message immediately
      _focusNode.unfocus(); // Hide keyboard
      ref.read(activeChatProvider.notifier).sendMessage(message, config);
      _scrollToBottom(force: true);
    } else {
      // Fill input field
      _messageController.text = message;
      _focusMessageInputAtEnd();
    }
  }

  /// Composer fill opacity when an image background is active.
  double _composerShellOpacity(ChatBackground background) {
    if (background.type != BackgroundType.image) return 1.0;
    return background.bubbleOpacity.clamp(0.0, 1.0);
  }

  double _composerFrostSigma(ChatBackground background) {
    if (background.type != BackgroundType.image) return 0;
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
              if (_showSlashSuggestions) ...[
                _composerOptionsDismissable(
                  child: _composerExpansionPanel(
                    opacity: composerOpacity,
                    frostSigma: composerFrostSigma,
                    child: SlashCommandSuggestions(
                      input: _messageController.text,
                      onSelect: _onSlashCommandSelected,
                      onDismiss: () =>
                          setState(() => _showSlashSuggestions = false),
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
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: 1,
                        hintText: l10n.typeMessage,
                        onSubmitted:
                            isDesktop ? (_) => _sendMessage() : null,
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _composerOptionsTapTarget(
                              child: ChromeIconButton(
                                density: ChromeIconButtonDensity.compact,
                                onPressed: () =>
                                    _setInputMenuVisible(!_showInputMenu),
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
                              density: ChromeIconButtonDensity.compact,
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
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: _focusMessageInputAtEnd,
                                child: const SizedBox(height: 34),
                              ),
                            ),
                            ChatVoiceInputButton(
                            controller: _messageController,
                            onAutoSend: _sendMessage,
                          ),
                          _composerOptionsTapTarget(
                            child: ChromeIconButton(
                              density: ChromeIconButtonDensity.compact,
                              onPressed: _onReplyChoicesButtonPressed,
                              tooltip: l10n.showReplyChoices,
                              isSelected: _showChoicePanel,
                              icon: Icon(
                                Icons.alt_route_outlined,
                                size: 22,
                                color: ref.watch(chatChoiceConfigProvider)
                                        .enabled
                                    ? null
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.38),
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
                                        .read(activeChatProvider.notifier)
                                        .cancelGeneration()
                                    : _sendMessage,
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Center(
                                    child: chatState.isGenerating
                                        ? DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: scheme.onPrimary,
                                              borderRadius:
                                                  BorderRadius.circular(2.5),
                                            ),
                                            child: const SizedBox(
                                              width: 12,
                                              height: 12,
                                            ),
                                          )
                                        : Icon(
                                            Icons.send_rounded,
                                            size: 18,
                                            color: scheme.onPrimary,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ],
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
                          _openImagineFromInput(chatState);
                        },
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _inputMenuPlainIconChip(
                    tooltip: AppLocalizations.of(context).appearanceSectionTitle,
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
    var currentValue = _messageController.value;
    if (!currentValue.selection.isValid) {
      currentValue = currentValue.copyWith(
        selection: TextSelection.collapsed(offset: currentValue.text.length),
      );
      _messageController.value = currentValue;
    }

    final newValue = MarkdownHotkeyService.applyFormat(
      value: currentValue,
      format: format,
    );
    _messageController.value = newValue;
    _focusNode.requestFocus();
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

  void _showExportDialog() {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.read(activeChatProvider);
    if (chatState.chat == null || chatState.character == null) {
      _showSnackBar(l10n.noChatToExport);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(l10n.exportChat),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exportChatWith(chatState.character!.name),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.messagesCount(chatState.messages.length),
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(l10n.chooseExportFormat),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _exportChat(useJsonl: false);
            },
            child: Text(l10n.json),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _exportChat(useJsonl: true);
            },
            child: Text(l10n.jsonlStFormat),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChat({bool useJsonl = true}) async {
    final chatState = ref.read(activeChatProvider);
    if (chatState.chat == null || chatState.character == null) return;

    final exportService = ref.read(chatExportServiceProvider);
    final activePersonaAsync = ref.read(activePersonaProvider);
    final userName = activePersonaAsync.valueOrNull?.name ??
        AppLocalizations.of(context).user;

    try {
      await exportService.exportAndShare(
        chatState.chat!,
        chatState.messages,
        chatState.character!,
        userName: userName,
        useJsonl: useJsonl,
        sharePositionOrigin: sharePositionOrigin(context),
      );
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.exportFailed(e.toString()));
    }
  }

  void _showImportDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.download, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(l10n.importChat),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importChatHistory),
            const SizedBox(height: 16),
            Text(
              l10n.supportedFormats,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('• ${l10n.jsonlSillyTavernFormat}'),
            Text('• ${l10n.jsonNativeTavernFormat}'),
            const SizedBox(height: 16),
            Text(
              l10n.importNote,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _importChat();
            },
            icon: const Icon(Icons.folder_open),
            label: Text(l10n.chooseFile),
          ),
        ],
      ),
    );
  }

  Future<void> _importChat() async {
    final l10n = AppLocalizations.of(context);
    final exportService = ref.read(chatExportServiceProvider);

    try {
      final result = await exportService.importFromFile();
      if (result == null) {
        _showSnackBar(l10n.noFileSelected);
        return;
      }

      // Show confirmation dialog with import details
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.importConfirmation),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.character}: ${result.characterName}'),
              Text('${l10n.user}: ${result.userName}'),
              Text('${l10n.messages}: ${result.messages.length}'),
              Text(
                '${l10n.date}: ${result.createDate.toString().split('.')[0]}',
              ),
              if (result.authorNote != null && result.authorNote!.isNotEmpty)
                Text('${l10n.hasAuthorsNote}: ${l10n.yes}'),
              const SizedBox(height: 16),
              Text(
                l10n.importMessagesToCurrentChat,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.import),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Import messages to current chat
      final chatState = ref.read(activeChatProvider);
      if (chatState.chat == null) {
        _showSnackBar(l10n.noActiveChat);
        return;
      }

      // Add imported messages
      final chatNotifier = ref.read(activeChatProvider.notifier);
      final uuid = const Uuid();
      final importedCount = await chatNotifier.importMessages(
        result.messages.map((importedMsg) {
          return importedMsg.toChatMessage(chatState.chat!.id, uuid.v4());
        }).toList(),
      );

      // Update author's note if present
      if (result.authorNote != null && result.authorNote!.isNotEmpty) {
        await chatNotifier.updateAuthorNoteSettings(
          chatId: widget.chatId,
          content: result.authorNote,
          depth: result.authorNoteDepth,
          enabled: result.authorNoteEnabled == true ? true : null,
        );
      }

      _showSnackBar(l10n.importedMessages(importedCount));
      _scrollToBottom(force: true);
    } catch (e) {
      _showSnackBar(l10n.importFailed(e.toString()));
    }
  }

  Future<void> _showClearConfirmation() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.clearMessages,
      body: l10n.clearMessagesConfirmation,
      confirmLabel: l10n.clear,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(activeChatProvider.notifier).clearMessages();
      if (mounted) {
        _showSnackBar(l10n.messagesCleared);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('${l10n.error}: $error');
      }
    }
  }

  Future<void> _saveChatManually() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(activeChatProvider.notifier).saveChatNow();
      if (mounted) {
        _showSnackBar(l10n.chatSaved);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('${l10n.error}: $error');
      }
    }
  }

  Future<bool> _handleUnsavedLeave() async {
    final l10n = AppLocalizations.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.unsavedChatTitle),
        content: Text(l10n.unsavedChatBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text(l10n.discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (action == 'save') {
      await ref.read(activeChatProvider.notifier).saveChatNow();
      return true;
    }
    if (action == 'discard') {
      await ref.read(activeChatProvider.notifier).discardUnsavedChanges();
      return true;
    }
    return false;
  }
}

class _MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final int messageIndex;
  final int messageDepth;
  final String chatId;
  final Character? character;
  final bool isGenerating;
  final bool isLast;
  final bool hasBackground;
  final bool hasImageBackground;
  final double bubbleOpacity;
  final String layoutMode;
  final bool highlighted;
  final void Function(int) onSwipe;
  final Future<void> Function(int)? onDeleteSwipe;
  final void Function(String) onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRegenerate;
  final VoidCallback onContinueFromHere;
  final VoidCallback onDeleteAndAfter;
  final VoidCallback onCreateBookmark;
  final VoidCallback onBranchChat;
  final VoidCallback? onGenerateImage;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.messageIndex,
    required this.messageDepth,
    required this.chatId,
    required this.character,
    required this.isGenerating,
    required this.isLast,
    this.hasBackground = false,
    this.hasImageBackground = false,
    this.bubbleOpacity = 0.8,
    this.layoutMode = 'bubble',
    this.highlighted = false,
    required this.onSwipe,
    this.onDeleteSwipe,
    required this.onEdit,
    required this.onDelete,
    this.onRegenerate,
    required this.onContinueFromHere,
    required this.onDeleteAndAfter,
    required this.onCreateBookmark,
    required this.onBranchChat,
    this.onGenerateImage,
  });

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  bool _isEditing = false;
  /// When true, touch text-selection is armed — skip outer long-press menu.
  bool _contentSelectionArmed = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  /// Display regex only after streaming completes (avoids flicker / partial HTML).
  String _displayContent() {
    final raw = widget.message.content;
    if (widget.isGenerating || raw.isEmpty) return raw;
    final placement = widget.message.role == MessageRole.user
        ? RegexPlacement.userInput
        : RegexPlacement.aiOutput;
    final characterId =
        widget.character?.id ?? widget.message.characterId;
    return ref.read(chatRegexFacadeProvider(characterId)).applyForDisplay(
          raw,
          placement: placement,
          depth: widget.messageDepth,
          characterName:
              widget.character?.name ?? widget.message.characterName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final hasSwipes = widget.message.swipes.length > 1;
    final showCharacterAvatar = ref.watch(
      appSettingsProvider.select((s) => s.showCharacterAvatar),
    );
    final showUserAvatar = ref.watch(
      appSettingsProvider.select((s) => s.showUserAvatar),
    );
    final avatarAboveBubble = ref.watch(
      appSettingsProvider.select((s) => s.avatarAboveBubble),
    );
    final bubbleBlurSigma = ref.watch(
      appSettingsProvider.select((s) => s.bubbleBlurSigma),
    );
    // Keep bubbles out of the opposite avatar column when that avatar is on
    // (side-by-side layout only).
    const avatarColumnWidth = 32.0 + 8.0;
    final showOwnAvatar =
        isUser ? showUserAvatar : showCharacterAvatar;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: _buildMessageDecoration(isUser),
      child: _isEditing
          ? _buildEditField()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show image attachments if available
                if (widget.message.hasAttachments) _buildAttachments(),
                // Show reasoning/thinking content if available
                if (!isUser && widget.message.hasReasoning)
                  _buildReasoningSection(),
                if (widget.isGenerating && widget.message.content.isEmpty)
                  const _TypingIndicator()
                else
                  MessageContentWidget(
                    content: _displayContent(),
                    textColor: ZephyrChatChrome.bubbleTextColor(
                      context,
                      isUser: isUser,
                    ),
                    isUser: isUser,
                    selectable: true,
                    onLongPress: () => _showMessageOptions(context),
                    onSelectionModeChanged: (armed) {
                      if (_contentSelectionArmed == armed) return;
                      setState(() => _contentSelectionArmed = armed);
                    },
                    isStreaming: widget.isGenerating,
                    messageId: widget.message.id,
                  ),
                if (!isUser && !widget.isGenerating)
                  DataBankCitationPreview(
                    message: widget.message,
                  ),
              ],
            ),
    );

    final bubbleColumn = Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {},
          // Step aside while touch selection is armed so SelectionArea can
          // receive long-press. Content / empty areas still open the menu.
          onLongPress: _contentSelectionArmed
              ? null
              : () => _showMessageOptions(context),
          child: ZephyrChatChrome.maybeFrosted(
            sigma: widget.hasImageBackground ? bubbleBlurSigma : 0,
            shape: ZephyrChatChrome.messageBubbleShape(
              isUser: isUser,
              radius: context.appChatBubbleCornerRadius,
            ),
            child: bubble,
          ),
        ),

        // Swipe controls
        if (hasSwipes && !widget.isGenerating)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: widget.message.currentSwipeIndex > 0
                      ? () => widget.onSwipe(
                            widget.message.currentSwipeIndex - 1,
                          )
                      : null,
                ),
                GestureDetector(
                  // Long press opens the Swipe Picker (ST 1.17+)
                  onLongPress: () => _openSwipePicker(context),
                  onTap: () => _openSwipePicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${widget.message.currentSwipeIndex + 1}/${widget.message.swipes.length}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textMuted),
                    ),
                  ),
                ),
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: widget.message.currentSwipeIndex <
                          widget.message.swipes.length - 1
                      ? () => widget.onSwipe(
                            widget.message.currentSwipeIndex + 1,
                          )
                      : null,
                ),
              ],
            ),
          ),
        if (!isUser && !widget.isGenerating)
          ChatTTSMessageButton(
            text: widget.message.content,
            ownerId: widget.chatId,
            sourceId: widget.message.id,
            characterId:
                widget.message.characterId ?? widget.character?.id,
          ),
        if (isUser && !_isEditing && !widget.isGenerating)
          ChromeIconButton(
            density: ChromeIconButtonDensity.compact,
            icon: const Icon(Icons.edit, size: 16),
            tooltip: AppLocalizations.of(context).edit,
            onPressed: () {
              _editController.text = widget.message.content;
              setState(() => _isEditing = true);
            },
          ),
      ],
    );

    if (avatarAboveBubble) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showOwnAvatar) ...[
              isUser ? _buildUserAvatar() : _buildAvatar(),
              const SizedBox(height: 6),
            ],
            // No side avatar columns — bubble can use the full row width.
            SizedBox(width: double.infinity, child: bubbleColumn),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser && showCharacterAvatar) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ] else if (isUser && showCharacterAvatar)
            const SizedBox(width: avatarColumnWidth),
          Flexible(child: bubbleColumn),
          if (isUser && showUserAvatar) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(),
          ] else if (!isUser && showUserAvatar)
            const SizedBox(width: avatarColumnWidth),
        ],
      ),
    );
  }

  void _openSwipePicker(BuildContext context) {
    SwipePickerSheet.show(
      context,
      message: widget.message,
      onSelect: (index) => widget.onSwipe(index),
      onDelete: (index) async {
        await widget.onDeleteSwipe?.call(index);
      },
    );
  }

  Decoration _buildMessageDecoration(bool isUser) {
    return ZephyrChatChrome.messageBubbleDecoration(
      context,
      isUser: isUser,
      transparent: widget.layoutMode == 'transparent',
      hasBackground: widget.hasBackground,
      bubbleOpacity: widget.bubbleOpacity,
      highlighted: widget.highlighted,
    );
  }

  Widget _buildAvatar() {
    final characterId =
        widget.character?.id ?? widget.message.characterId;
    final l10n = AppLocalizations.of(context);
    final avatar = widget.character?.assets?.avatarPath != null
        ? CharacterAvatarCircle(
            imagePath: widget.character!.assets!.avatarPath!,
            radius: 16,
            errorBuilder: (_, __, ___) => const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 16),
            ),
          )
        : const CircleAvatar(
            radius: 16,
            child: Icon(Icons.person, size: 16),
          );

    if (characterId == null || characterId.isEmpty) return avatar;

    return Tooltip(
      message: l10n.viewCharacter,
      child: GestureDetector(
        onTap: () => context.push('/characters/$characterId'),
        child: avatar,
      ),
    );
  }

  Widget _buildUserAvatar() {
    final scheme = Theme.of(context).colorScheme;
    final persona = ref.watch(activePersonaProvider).valueOrNull;
    final path = persona?.avatarPath;
    Widget fallback() => CircleAvatar(
          radius: 16,
          backgroundColor: ZephyrChatChrome.userAvatarFill(scheme),
          child: Icon(Icons.person, size: 16, color: scheme.primary),
        );
    if (path != null && path.isNotEmpty) {
      return CharacterAvatarCircle(
        imagePath: path,
        radius: 16,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    return fallback();
  }

  /// Build the reasoning/thinking section for AI messages
  Widget _buildReasoningSection() {
    final showReasoning = ref.watch(
      appSettingsProvider.select((s) => s.showReasoning),
    );
    if (!showReasoning) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final reasoning = widget.message.currentReasoning;
    if (reasoning == null || reasoning.isEmpty) {
      return const SizedBox.shrink();
    }

    // During streaming, show the streaming version
    if (widget.isGenerating && widget.isLast) {
      return StreamingReasoningWidget(
        reasoning: reasoning,
        isStreaming: true,
        label: l10n.thinkingInProgress,
      );
    }

    // For completed messages, show the collapsible version
    return ReasoningWidget(
      reasoning: reasoning,
      initiallyExpanded: false,
      label: l10n.thinking,
    );
  }

  /// Build image attachments grid for messages
  Widget _buildAttachments() {
    final attachments = widget.message.attachments;
    if (attachments.isEmpty) return const SizedBox.shrink();

    // For single image, show larger preview
    if (attachments.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => _showImagePreview(attachments[0]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 200),
              child: Image.file(
                File(attachments[0].path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 150,
                  height: 100,
                  color: AppTheme.darkBackground,
                  child: const Icon(
                    Icons.broken_image,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // For multiple images, show a grid
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: attachments.map((attachment) {
          return GestureDetector(
            onTap: () => _showImagePreview(attachment),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(attachment.path),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.darkBackground,
                  child: const Icon(
                    Icons.broken_image,
                    size: 20,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Show full-screen image preview
  void _showImagePreview(ChatAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(attachment.path),
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 200,
                      height: 200,
                      color: AppTheme.darkCard,
                      child: const Icon(
                        Icons.broken_image,
                        size: 48,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: ChromeIconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                widget.onEdit(_editController.text);
                setState(() => _isEditing = false);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }

  void _showMessageOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isAssistant = widget.message.role == MessageRole.assistant;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.copy, color: scheme.onSurfaceVariant),
                title: Text(l10n.copy),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(
                    ClipboardData(text: widget.message.content),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.copiedToClipboard),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: scheme.onSurfaceVariant),
                title: Text(l10n.edit),
                onTap: () {
                  Navigator.pop(context);
                  _editController.text = widget.message.content;
                  setState(() => _isEditing = true);
                },
              ),
              if (isAssistant && widget.onRegenerate != null)
                ListTile(
                  leading: Icon(Icons.refresh, color: scheme.primary),
                  title: Text(l10n.regenerate),
                  subtitle: Text(l10n.generateNewResponse),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onRegenerate!();
                  },
                ),
              ListTile(
                leading: Icon(Icons.play_arrow, color: scheme.tertiary),
                title: Text(l10n.continueFromHere),
                subtitle: Text(
                  widget.message.role == MessageRole.user
                      ? l10n.deleteMessagesAfterAndRegenerate
                      : l10n.deleteMessagesAfterThis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onContinueFromHere();
                },
              ),
              ListTile(
                leading: Icon(Icons.call_split, color: scheme.secondary),
                title: Text(l10n.newBranchChat),
                subtitle: Text(l10n.newBranchChatHint),
                onTap: () {
                  Navigator.pop(context);
                  widget.onBranchChat();
                },
              ),
              ListTile(
                leading: Icon(Icons.bookmark_add, color: scheme.tertiary),
                title: Text(l10n.createBookmark),
                subtitle: Text(l10n.saveAsCheckpoint),
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreateBookmark();
                },
              ),
              if (widget.onGenerateImage != null)
                ListTile(
                  leading: Icon(Icons.auto_awesome, color: scheme.primary),
                  title: Text(l10n.generateImagesUsingAi),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onGenerateImage!();
                  },
                ),
              Divider(color: scheme.outlineVariant),
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(l10n.deleteThisMessage),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
              ),
              if (!widget.isLast)
                ListTile(
                  leading: Icon(Icons.delete_sweep, color: scheme.error),
                  title: Text(
                    l10n.deleteThisAndAllAfter,
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDeleteAndAfter();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animationValue = ((_controller.value + delay) % 1.0);
            final size = 4.0 + (animationValue * 4.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

enum _ModelThinkingStep { model, effort }

/// Bottom drawer: choose model, then reasoning effort.
class _ModelThinkingDrawer extends ConsumerStatefulWidget {
  const _ModelThinkingDrawer();

  @override
  ConsumerState<_ModelThinkingDrawer> createState() =>
      _ModelThinkingDrawerState();
}

class _ModelThinkingDrawerState extends ConsumerState<_ModelThinkingDrawer> {
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
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                effort == current
                    ? Icons.check_circle
                    : Icons.circle_outlined,
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
