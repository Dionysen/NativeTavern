import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:native_tavern/domain/services/rpg_scenario_package_service.dart';
import 'package:native_tavern/domain/services/tts_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/controllers/chat_tts_autoplay_controller.dart';
import 'package:native_tavern/presentation/providers/bookmark_providers.dart';
import 'package:native_tavern/presentation/providers/background_providers.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/providers/chat_extension_providers.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/providers/rpg_chat_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/providers/story_providers.dart';
import 'package:native_tavern/presentation/providers/tts_providers.dart';
import 'package:native_tavern/presentation/providers/world_info_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_message_bubble.dart';
import 'package:native_tavern/presentation/widgets/chat/author_note_dialog.dart';
import 'package:native_tavern/presentation/widgets/chat/bookmark_dialog.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_tail_scroll.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_background_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/chat_composer.dart';
import 'package:native_tavern/presentation/widgets/chat/memory_context_usage_sheet.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_scaffold.dart';
import 'package:native_tavern/presentation/widgets/play/ai_play_feature_gate.dart';
import 'package:native_tavern/presentation/providers/context_usage_providers.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/widgets/chat/image_generation_dialog.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/domain/services/image_prompt_composer.dart';
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

  final TextEditingController _messageController = TextEditingController();
  final ChatTailScrollController _scrollController = ChatTailScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _generatingQuickImage = false;
  String? _lastAutoImageGenKey;
  final ChatTTSAutoPlayController _ttsAutoPlayController =
      ChatTTSAutoPlayController();
  final Live2DCharacterController _live2DController =
      Live2DCharacterController();
  late final TTSStopAction _stopTts;
  final Map<String, GlobalKey<ChatMessageBubbleState>> _messageKeys = {};
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

  /// Height of the floating bottom chrome (composer + tool/rpg panels).
  /// Message list extends under it; this inset keeps the latest bubble readable.
  double _bottomChromeHeight = 96;

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
    _scheduleChatLoad(applyInitialDraft: true);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId &&
        oldWidget.initialMessageId == widget.initialMessageId) {
      return;
    }
    _initialMessageJumpScheduled = false;
    _highlightedMessageId = null;
    _messageKeys.clear();
    _chatAppBarVisible = true;
    _appBarScrollAccumulator = 0;
    // Side nav uses go_router.go; the chat pageKey is the route pattern, so the
    // same State is reused when only :id changes and must reload explicitly.
    if (oldWidget.chatId != widget.chatId) {
      _messageController.clear();
      _scheduleChatLoad(applyInitialDraft: true);
    }
  }

  void _scheduleChatLoad({required bool applyInitialDraft}) {
    final chatId = widget.chatId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.chatId != chatId) return;
      ref.read(activeChatProvider.notifier).loadChat(chatId);
      ref.read(bookmarkNotifierProvider.notifier).loadBookmarks(chatId);
      ref.read(rpgChatProvider(chatId).notifier).load();
      // Refresh context usage to ensure fresh calculation
      // This handles cases where world info was updated while not in chat
      refreshContextUsageProviders(ref);
      if (!applyInitialDraft) return;
      final draft = widget.initialDraft?.trim();
      if (draft != null && draft.isNotEmpty) {
        _messageController.text = draft;
      }
    });
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

  void _generateImageForCurrentReply() {
    final chatState = ref.read(activeChatProvider);
    final source = lastCharacterTextReply(chatState.messages);
    if (source == null) {
      _showSnackBar(AppLocalizations.of(context).noCharacterReplyForImage);
      return;
    }
    unawaited(_generateImageFromMessage(source));
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
    final hideOnScroll = ref.read(appSettingsProvider).hideChatAppBarOnScroll;
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
        position
            .animateTo(
          target,
          duration: duration,
          curve: soft ? Curves.easeOut : Curves.easeOutCubic,
        )
            .whenComplete(() {
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

  bool _ensureApiConfigured() {
    final config = ref.read(llmConfigProvider);
    if (_isApiConfigured(config)) return true;
    _showApiConfigurationDialog();
    return false;
  }

  /// Composer already checked the API and cleared the draft.
  Future<void> _sendPreparedMessage(
    String content,
    List<ChatAttachment> attachments,
  ) async {
    final config = ref.read(llmConfigProvider);
    await ref.read(activeChatProvider.notifier).sendMessage(
          content,
          config,
          attachments: attachments,
        );
  }

  void _continueFromComposer() {
    final config = ref.read(llmConfigProvider);
    ref.read(activeChatProvider.notifier).continueGeneration(config);
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

  Future<List<ChatAttachment>> _saveGeneratedImages(
    ImageGenResult result, {
    int? width,
    int? height,
  }) async {
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
          width: width,
          height: height,
        ),
      );
    }
    return attachments;
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
        _reconcileStalePendingImageGens();
      } else if (messageCountChanged) {
        // Soft pin: follow only when already near bottom / not dragging.
        _scrollToBottomImmediate();
      }
      _handleChatTTSChange(previous, next);
      _maybeAutoGenerateImageAfterReply(previous, next);
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

                          // Messages fill the viewport; composer floats on top so
                          // bubbles can scroll behind / under the input shell.
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                chatState.isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _buildMessagesAreaWithScrollButton(
                                        chatState,
                                      ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: _MeasureSize(
                                    onChange: _onBottomChromeSize,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (kRpgProductUiEnabled)
                                          RpgGamePanel(
                                            chatId: widget.chatId,
                                            onDisable: _toggleRpgMode,
                                          ),
                                        ToolActivityPanel(
                                            chatId: widget.chatId),
                                        ChatComposer(
                                          chatId: widget.chatId,
                                          controller: _messageController,
                                          focusNode: _focusNode,
                                          chatState: chatState,
                                          generatingImage:
                                              _generatingQuickImage,
                                          ensureApiConfigured:
                                              _ensureApiConfigured,
                                          onSend: _sendPreparedMessage,
                                          onContinue: _continueFromComposer,
                                          onAfterSend: () =>
                                              _scrollToBottom(force: true),
                                          onOpenImagine: _openImagineFromInput,
                                          onGenerateImageForCurrentReply:
                                              _generateImageForCurrentReply,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
            !chatState.messages.last.isGeneratedImage &&
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
                  color:
                      hasAuthorNote ? AppTheme.accentColor : AppTheme.textMuted,
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
                  context.openShell('/characters/$characterId');
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
          onTap: () => context.openShell('/characters/$characterId'),
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
    final showButton = _showScrollToBottomButton && layoutMode != 'visualNovel';
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
            // Sit just above the floating composer chrome.
            bottom: _bottomChromeHeight + 12,
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
    final background =
        ref.watch(effectiveBackgroundProvider(characterId)).valueOrNull ??
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
              child: Padding(
                padding: EdgeInsets.only(bottom: _bottomChromeHeight),
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
                  onQuickImagine: ref.watch(imageGenSettingsProvider).enabled
                      ? _generateImageFromMessage
                      : null,
                ),
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
    final live2dEnabled = chatState.character?.assets?.live2d?.enabled == true;
    final hasBackground = _hasFloatingChatStage(
      background,
      live2dEnabled: live2dEnabled,
    );
    final frostBubbles = _hasFrostableChatStage(
      background,
      live2dEnabled: live2dEnabled,
    );

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
            _pendingOlderMaxExtent = _scrollController.position.maxScrollExtent;
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
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + _bottomChromeHeight),
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

          return ChatMessageBubble(
            key: _messageKeys.putIfAbsent(
              message.id,
              () => GlobalKey<ChatMessageBubbleState>(),
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
            frostOverBackground: frostBubbles,
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
            onRegenerate: message.role == MessageRole.assistant &&
                    !message.isGeneratedImage
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
            onGenerateImage: ref.read(imageGenSettingsProvider).enabled &&
                    !message.isPendingImageGen &&
                    !_generatingQuickImage &&
                    !ref.watch(imageGenStateProvider).isGenerating
                ? () {
                    _showImageGenerationDialog(message, chatState.character);
                  }
                : null,
            onQuickImagine: ref.watch(imageGenSettingsProvider).enabled &&
                    message.role == MessageRole.assistant &&
                    !message.isGeneratedImage &&
                    !message.isPendingImageGen &&
                    !_generatingQuickImage &&
                    !ref.watch(imageGenStateProvider).isGenerating
                ? () => _generateImageFromMessage(message)
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

  void _maybeAutoGenerateImageAfterReply(
    ActiveChatState? previous,
    ActiveChatState next,
  ) {
    // Fire on the generating true→false edge only. Streamed replies usually
    // already have their final text in state before isGenerating flips, so
    // requiring a content diff vs `previous` permanently skips auto-gen.
    if (previous?.isGenerating != true || next.isGenerating) return;
    if (next.error != null) return;

    final settings = ref.read(imageGenSettingsProvider);
    if (!settings.enabled || !settings.autoGenerateOnReply) return;
    if (_generatingQuickImage || ref.read(imageGenStateProvider).isGenerating) {
      return;
    }

    final nextLast = lastCharacterTextReply(next.messages);
    if (nextLast == null ||
        nextLast.content.trim().isEmpty ||
        nextLast.isPendingImageGen) {
      return;
    }

    final key =
        '${nextLast.id}:${nextLast.currentSwipeIndex}:${nextLast.content.hashCode}';
    if (_lastAutoImageGenKey == key) return;
    _lastAutoImageGenKey = key;
    unawaited(_generateImageFromMessage(nextLast));
  }

  Future<void> _openImagineFromInput(ActiveChatState chatState) async {
    if (_generatingQuickImage || ref.read(imageGenStateProvider).isGenerating) {
      return;
    }
    final typed = _messageController.text.trim();
    final lastAssistant = lastCharacterTextReply(chatState.messages);
    final settings = ref.read(imageGenSettingsProvider);
    final speaker = lastAssistant == null
        ? chatState.character
        : chatState.characterForMessage(lastAssistant);
    final launch = await ImageGenerationDialog.show(
      context,
      basePrompt: typed.isNotEmpty ? typed : (lastAssistant?.content ?? ''),
      characterName: speaker?.name ?? chatState.character?.name,
      characterAppearance:
          speaker?.sdAppearance ?? chatState.character?.sdAppearance,
      personaAppearance: settings.personaAppearancePrefix,
      mode: ImageGenMode.free,
      autoCompose: typed.isEmpty,
    );
    if (launch == null || !mounted) return;
    unawaited(
      _runAsyncImageGeneration(
        request: launch.request,
        character: speaker ?? chatState.character,
        sourceMessage: lastAssistant,
      ),
    );
  }

  /// Clear stuck "Generating..." tiles when reopening a chat with no live job.
  void _reconcileStalePendingImageGens() {
    if (!mounted) return;
    if (_generatingQuickImage || ref.read(imageGenStateProvider).isGenerating) {
      return;
    }
    final hasPending = ref
        .read(activeChatProvider)
        .messages
        .any((message) => message.isPendingImageGen);
    if (!hasPending) return;
    unawaited(
        ref.read(activeChatProvider.notifier).clearStalePendingImageGens());
  }

  /// Picture this character line without blocking the chat UI.
  /// Makes [ImageGenSettings.imagesPerReply] pictures (compose once, then loop).
  Future<void> _generateImageFromMessage(ChatMessage source) async {
    if (_generatingQuickImage || ref.read(imageGenStateProvider).isGenerating) {
      return;
    }
    if (source.role != MessageRole.assistant ||
        source.isGeneratedImage ||
        source.isPendingImageGen) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(imageGenSettingsProvider);
    if (!settings.enabled) {
      _showSnackBar('${l10n.imageGeneration}: ${l10n.configureNow}');
      return;
    }

    if (source.content.trim().isEmpty) {
      _showSnackBar(l10n.noCharacterReplyForImage);
      return;
    }

    // Capture providers before awaits so completion survives leaving the screen.
    final chatNotifier = ref.read(activeChatProvider.notifier);
    final imageGenNotifier = ref.read(imageGenStateProvider.notifier);
    final settingsNotifier = ref.read(imageGenSettingsProvider.notifier);
    final availableModels = ref.read(availableModelsProvider);
    final chatState = ref.read(activeChatProvider);
    final speaker =
        chatState.characterForMessage(source) ?? chatState.character;
    final imageCount = settings.imagesPerReply.clamp(1, 4);
    final attachMode = settings.displayMode == ImageGenDisplayMode.attach;
    final noImageGenerated = l10n.noImageGenerated;
    final ownerChatId = widget.chatId;
    final selectedModel = availableModels.contains(settings.model)
        ? settings.model
        : (availableModels.isNotEmpty ? availableModels.first : settings.model);
    if (selectedModel.isNotEmpty && selectedModel != settings.model) {
      settingsNotifier.setModel(selectedModel);
    }

    setState(() => _generatingQuickImage = true);

    try {
      final sceneTags = await _composeSceneTags(
        sceneText: source.content,
        settings: settings,
        characterName: speaker?.name,
        characterAppearance: speaker?.sdAppearance,
      );
      if (sceneTags.trim().isEmpty) {
        if (mounted) _showSnackBar(noImageGenerated);
        return;
      }

      const composer = ImagePromptComposer();
      final assembled = composer.assembleFinalPrompt(
        sceneTags: sceneTags,
        commonPrefix: settings.effectiveCommonPromptPrefix,
        characterAppearance: speaker?.sdAppearance,
        personaAppearance: settings.personaAppearancePrefix,
      );

      final request = ImageGenRequest(
        prompt: assembled,
        negativePrompt: settings.effectiveNegativePrompt,
        width: settings.defaultWidth,
        height: settings.defaultHeight,
        steps: settings.defaultSteps,
        cfgScale: settings.defaultCfgScale,
        sampler: settings.defaultSampler,
        scheduler: settings.defaultScheduler,
        mode: ImageGenMode.lastMessage,
        model: selectedModel,
      );

      // Attach mode: one strip with N slots. Separate: one bubble per image.
      _ImageGenPlaceholder? attachPlaceholder;
      if (attachMode) {
        attachPlaceholder = await _createImageGenPlaceholder(
          chatNotifier: chatNotifier,
          displayMode: settings.displayMode,
          character: speaker,
          sourceMessage: source,
          width: settings.defaultWidth,
          height: settings.defaultHeight,
          pendingCount: imageCount,
        );
        if (attachPlaceholder == null) return;
      }

      for (var i = 0; i < imageCount; i++) {
        // Separate bubbles must stay on the chat that started generation.
        if (!attachMode && !chatNotifier.isShowingChat(ownerChatId)) {
          break;
        }
        final placeholder = attachMode
            ? attachPlaceholder!
            : await _createImageGenPlaceholder(
                chatNotifier: chatNotifier,
                displayMode: settings.displayMode,
                character: speaker,
                sourceMessage: source,
                width: settings.defaultWidth,
                height: settings.defaultHeight,
                pendingCount: 1,
              );
        if (placeholder == null) continue;

        try {
          final result = await imageGenNotifier.generate(request);
          if (result == null || result.images.isEmpty) {
            await _failImageGenPlaceholder(
              placeholder,
              noImageGenerated,
              chatNotifier: chatNotifier,
            );
            break;
          }
          await _completeImageGenPlaceholder(
            placeholder,
            result,
            character: speaker,
            request: request,
            remainingPending: attachMode ? (imageCount - i - 1) : 0,
            chatNotifier: chatNotifier,
          );
        } catch (error) {
          await _failImageGenPlaceholder(
            placeholder,
            '$error',
            chatNotifier: chatNotifier,
          );
          break;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _generatingQuickImage = false);
      } else {
        _generatingQuickImage = false;
      }
    }
  }

  Future<String> _composeSceneTags({
    required String sceneText,
    required ImageGenSettings settings,
    String? characterName,
    String? characterAppearance,
  }) async {
    const composer = ImagePromptComposer();
    final fallback = composer.fallbackPrompt(
      sceneText: sceneText,
      characterName: characterName,
    );
    final config = ref.read(llmConfigProvider);
    if (config.apiKey.isEmpty && config.apiUrl.isEmpty) return fallback;

    try {
      final generated = await ref.read(llmServiceProvider).generate(
            composer.composeMessages(
              sceneText: sceneText,
              characterName: characterName,
              instruction: settings.effectiveLlmImagePromptInstruction,
              characterAppearance: characterAppearance,
              personaAppearance: settings.personaAppearancePrefix,
            ),
            ImagePromptComposer.llmConfigForCompose(config),
          );
      final prompt = composer.normalizeModelOutput(generated);
      return prompt.isEmpty ? fallback : prompt;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _runAsyncImageGeneration({
    required ImageGenRequest request,
    Character? character,
    ChatMessage? sourceMessage,
  }) async {
    if (_generatingQuickImage || ref.read(imageGenStateProvider).isGenerating) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final chatNotifier = ref.read(activeChatProvider.notifier);
    final imageGenNotifier = ref.read(imageGenStateProvider.notifier);
    final noImageGenerated = l10n.noImageGenerated;
    final displayMode = ref.read(imageGenSettingsProvider).displayMode;
    final placeholder = await _createImageGenPlaceholder(
      chatNotifier: chatNotifier,
      displayMode: displayMode,
      character: character,
      sourceMessage: sourceMessage,
      width: request.width,
      height: request.height,
      pendingCount: 1,
    );
    if (placeholder == null) return;

    setState(() => _generatingQuickImage = true);

    try {
      final result = await imageGenNotifier.generate(request);
      if (result == null || result.images.isEmpty) {
        await _failImageGenPlaceholder(
          placeholder,
          noImageGenerated,
          chatNotifier: chatNotifier,
        );
        return;
      }
      await _completeImageGenPlaceholder(
        placeholder,
        result,
        character: character,
        request: request,
        remainingPending: 0,
        chatNotifier: chatNotifier,
      );
    } catch (error) {
      await _failImageGenPlaceholder(
        placeholder,
        '$error',
        chatNotifier: chatNotifier,
      );
    } finally {
      if (mounted) {
        setState(() => _generatingQuickImage = false);
      } else {
        _generatingQuickImage = false;
      }
    }
  }

  /// Creates an in-chat placeholder for async image generation.
  Future<_ImageGenPlaceholder?> _createImageGenPlaceholder({
    required ActiveChatNotifier chatNotifier,
    required ImageGenDisplayMode displayMode,
    Character? character,
    ChatMessage? sourceMessage,
    required int width,
    required int height,
    int pendingCount = 1,
  }) async {
    final chatState = chatNotifier.snapshot;
    final speaker = character ?? chatState.character;
    final aspect = height > 0 ? width / height : 1.0;
    final count = pendingCount.clamp(1, 4);

    if (displayMode == ImageGenDisplayMode.attach) {
      final attachTarget = _resolveAttachTarget(sourceMessage, chatState);
      if (attachTarget != null) {
        final metadata = Map<String, dynamic>.from(attachTarget.metadata)
          ..[ChatMessage.pendingImageGenMetadataKey] = true
          ..[ChatMessage.pendingImageGenAspectMetadataKey] = aspect
          ..[ChatMessage.pendingImageGenCountMetadataKey] = count;
        await chatNotifier.patchMessage(attachTarget.id, metadata: metadata);
        return _ImageGenPlaceholder(
          messageId: attachTarget.id,
          attachMode: true,
          dedicatedBubble: false,
        );
      }

      final created = await chatNotifier.addLocalMessage(
        role: MessageRole.assistant,
        content: '',
        characterId: speaker?.id,
        characterName: speaker?.name,
        metadata: {
          ChatMessage.generatedImageMetadataKey: true,
          ChatMessage.generatedImageLayoutMetadataKey:
              ChatMessage.generatedImageLayoutAttach,
          ChatMessage.pendingImageGenMetadataKey: true,
          ChatMessage.pendingImageGenAspectMetadataKey: aspect,
          ChatMessage.pendingImageGenCountMetadataKey: count,
        },
      );
      if (created == null) return null;
      return _ImageGenPlaceholder(
        messageId: created.id,
        attachMode: true,
        dedicatedBubble: true,
      );
    }

    final created = await chatNotifier.addLocalMessage(
      role: MessageRole.assistant,
      content: '',
      characterId: speaker?.id,
      characterName: speaker?.name,
      metadata: {
        ChatMessage.generatedImageMetadataKey: true,
        ChatMessage.pendingImageGenMetadataKey: true,
        ChatMessage.pendingImageGenAspectMetadataKey: aspect,
        ChatMessage.pendingImageGenCountMetadataKey: count,
      },
    );
    if (created == null) return null;
    return _ImageGenPlaceholder(
      messageId: created.id,
      attachMode: false,
      dedicatedBubble: true,
    );
  }

  Future<void> _completeImageGenPlaceholder(
    _ImageGenPlaceholder placeholder,
    ImageGenResult result, {
    Character? character,
    required ImageGenRequest request,
    required int remainingPending,
    required ActiveChatNotifier chatNotifier,
  }) async {
    final failSavePrefix =
        mounted ? AppLocalizations.of(context).failedToSaveImage : null;
    final generationCompleteLabel =
        mounted ? AppLocalizations.of(context).generationComplete : null;
    final noImageGenerated = mounted
        ? AppLocalizations.of(context).noImageGenerated
        : 'No image generated';
    try {
      final attachments = await _saveGeneratedImages(
        result,
        width: request.width,
        height: request.height,
      );
      if (attachments.isEmpty) {
        await _failImageGenPlaceholder(
          placeholder,
          noImageGenerated,
          chatNotifier: chatNotifier,
        );
        return;
      }

      final message =
          await chatNotifier.resolveMessageById(placeholder.messageId);
      if (message == null) return;

      if (placeholder.attachMode) {
        final nextAttachments = [...message.attachments, ...attachments];
        final metadata = remainingPending > 0
            ? (Map<String, dynamic>.from(message.metadata)
              ..[ChatMessage.pendingImageGenMetadataKey] = true
              ..[ChatMessage.pendingImageGenAspectMetadataKey] =
                  message.pendingImageGenAspect
              ..[ChatMessage.pendingImageGenCountMetadataKey] =
                  remainingPending.clamp(1, 4))
            : _metadataWithoutPending(message.metadata);
        await chatNotifier.persistMessageUpdate(
          message.copyWith(
            attachments: nextAttachments,
            metadata: metadata,
          ),
        );
      } else {
        // First image replaces the placeholder bubble; extras get new bubbles.
        await chatNotifier.persistMessageUpdate(
          message.copyWith(
            attachments: [attachments.first],
            metadata: _metadataWithoutPending(message.metadata),
          ),
        );
        final speaker = character ?? chatNotifier.activeCharacter;
        for (final attachment in attachments.skip(1)) {
          // Only append extra bubbles while this chat is still active.
          if (!chatNotifier.isShowingChat(message.chatId)) break;
          await chatNotifier.addLocalMessage(
            role: MessageRole.assistant,
            content: '',
            attachments: [attachment],
            characterId: speaker?.id,
            characterName: speaker?.name,
            metadata: const {
              ChatMessage.generatedImageMetadataKey: true,
            },
          );
        }
      }

      if (mounted && generationCompleteLabel != null) {
        _showSnackBar('$generationCompleteLabel (${attachments.length})');
      }
    } catch (error) {
      final message = failSavePrefix != null
          ? failSavePrefix('$error')
          : 'Failed to save image: $error';
      await _failImageGenPlaceholder(
        placeholder,
        message,
        chatNotifier: chatNotifier,
      );
    }
  }

  Future<void> _failImageGenPlaceholder(
    _ImageGenPlaceholder placeholder,
    String error, {
    required ActiveChatNotifier chatNotifier,
  }) async {
    final message =
        await chatNotifier.resolveMessageById(placeholder.messageId);
    if (message != null) {
      if (placeholder.dedicatedBubble && message.attachments.isEmpty) {
        await chatNotifier.persistMessageDelete(placeholder.messageId);
      } else {
        await chatNotifier.persistMessageUpdate(
          message.copyWith(metadata: _metadataWithoutPending(message.metadata)),
        );
      }
    }
    if (mounted) _showCommandError(error);
  }

  Map<String, dynamic> _metadataWithoutPending(Map<String, dynamic> metadata) {
    final next = Map<String, dynamic>.from(metadata)
      ..remove(ChatMessage.pendingImageGenMetadataKey)
      ..remove(ChatMessage.pendingImageGenAspectMetadataKey)
      ..remove(ChatMessage.pendingImageGenCountMetadataKey);
    return next;
  }

  ChatMessage? _resolveAttachTarget(
    ChatMessage? sourceMessage,
    ActiveChatState chatState,
  ) {
    if (sourceMessage != null &&
        sourceMessage.role == MessageRole.assistant &&
        !sourceMessage.isGeneratedImage) {
      return sourceMessage;
    }
    return lastCharacterTextReply(chatState.messages);
  }

  void _showImageGenerationDialog(
    ChatMessage message,
    Character? character,
  ) async {
    if (_generatingQuickImage || ref.read(imageGenStateProvider).isGenerating) {
      return;
    }
    final settings = ref.read(imageGenSettingsProvider);
    final launch = await ImageGenerationDialog.show(
      context,
      basePrompt: message.content,
      characterName: character?.name,
      characterAppearance: character?.sdAppearance,
      personaAppearance: settings.personaAppearancePrefix,
      mode: message.role == MessageRole.assistant
          ? ImageGenMode.lastMessage
          : ImageGenMode.free,
      autoCompose: message.role == MessageRole.assistant,
    );

    if (launch == null || !mounted) return;
    final chatState = ref.read(activeChatProvider);
    final speaker =
        message.role == MessageRole.assistant ? character : chatState.character;
    final source =
        message.role == MessageRole.assistant && !message.isGeneratedImage
            ? message
            : lastCharacterTextReply(chatState.messages);
    unawaited(
      _runAsyncImageGeneration(
        request: launch.request,
        character: speaker ?? chatState.character,
        sourceMessage: source,
      ),
    );
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
      final characterId = chatState.character?.id ?? chat?.characterId;
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
    context.openShell('/chat/$newChatId');
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
    context.openShell('/chat/$newChatId');
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

  /// True when chat chrome should float over a visual stage (bg / Live2D).
  bool _hasFloatingChatStage(
    ChatBackground background, {
    bool? live2dEnabled,
  }) {
    final live2d = live2dEnabled ??
        ref.read(activeChatProvider).character?.assets?.live2d?.enabled == true;
    return background.type != BackgroundType.none || live2d;
  }

  /// Frosted glass only helps over textured stages (image / Live2D).
  bool _hasFrostableChatStage(
    ChatBackground background, {
    bool? live2dEnabled,
  }) {
    final live2d = live2dEnabled ??
        ref.read(activeChatProvider).character?.assets?.live2d?.enabled == true;
    return background.type == BackgroundType.image || live2d;
  }

  void _onBottomChromeSize(Size size) {
    if (!mounted) return;
    if ((size.height - _bottomChromeHeight).abs() < 0.5) return;
    setState(() => _bottomChromeHeight = size.height);
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

/// Tracks where an in-flight image generation placeholder lives.
class _ImageGenPlaceholder {
  final String messageId;
  final bool attachMode;
  final bool dedicatedBubble;

  const _ImageGenPlaceholder({
    required this.messageId,
    required this.attachMode,
    required this.dedicatedBubble,
  });
}

/// Reports child layout size after each change (for floating chrome inset).
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onChange,
    required Widget child,
  }) : super(child: child);

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final next = size;
    if (_oldSize == next) return;
    _oldSize = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(next));
  }
}
