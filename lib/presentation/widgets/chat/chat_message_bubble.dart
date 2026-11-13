import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/core/utils/image_save_utils.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/data/models/status_block_config.dart';
import 'package:native_tavern/domain/services/status_block_parser.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/providers/regex_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/chat/data_bank_citation_preview.dart';
import 'package:native_tavern/presentation/widgets/chat/message_content_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/reasoning_widget.dart';
import 'package:native_tavern/presentation/widgets/chat/status_block_panel.dart';
import 'package:native_tavern/presentation/widgets/chat/swipe_picker_sheet.dart';
import 'package:native_tavern/presentation/widgets/chat/tts_playback_controls.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

class ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final int messageIndex;
  final int messageDepth;
  final String chatId;
  final Character? character;
  final bool isGenerating;
  final bool isLast;
  final bool hasBackground;
  final bool frostOverBackground;
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
  final VoidCallback? onQuickImagine;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.messageIndex,
    required this.messageDepth,
    required this.chatId,
    required this.character,
    required this.isGenerating,
    required this.isLast,
    this.hasBackground = false,
    this.frostOverBackground = false,
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
    this.onQuickImagine,
  });

  @override
  ConsumerState<ChatMessageBubble> createState() => ChatMessageBubbleState();
}

class ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
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
  String _rawDisplayContent() {
    final raw = widget.message.content;
    if (widget.isGenerating || raw.isEmpty) return raw;
    final placement = widget.message.role == MessageRole.user
        ? RegexPlacement.userInput
        : RegexPlacement.aiOutput;
    final characterId = widget.character?.id ?? widget.message.characterId;
    return ref.read(chatRegexFacadeProvider(characterId)).applyForDisplay(
          raw,
          placement: placement,
          depth: widget.messageDepth,
          characterName: widget.character?.name ?? widget.message.characterName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final hasSwipes = widget.message.swipes.length > 1;
    final rawDisplay = _rawDisplayContent();
    final parsedStatus = isUser ? null : StatusBlockParser.parse(rawDisplay);
    final displayContent = isUser
        ? rawDisplay
        : (parsedStatus?.contentWithoutStatus ?? rawDisplay);
    final embeddedStatus = isUser
        ? null
        : (parsedStatus?.snapshot ??
            StatusBlockSnapshot.fromMetadata(widget.message.metadata));
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
    final showOwnAvatar = isUser ? showUserAvatar : showCharacterAvatar;
    final isGeneratedImage = widget.message.isGeneratedImage;
    final isPendingImageGen = widget.message.isPendingImageGen;
    final isSeparateGeneratedImageBubble = isGeneratedImage &&
        !widget.message.isAttachedGeneratedImage &&
        widget.message.content.trim().isEmpty;
    final isEdgeToEdgeGeneratedImage = isSeparateGeneratedImageBubble;
    final bubbleShape = ZephyrChatChrome.messageBubbleShape(
      isUser: isUser,
      radius: context.appChatBubbleCornerRadius,
    );
    final bubble = Container(
      // Separate-bubble generated pictures fill with no inner padding.
      padding: isEdgeToEdgeGeneratedImage
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
      decoration: _buildMessageDecoration(isUser),
      child: _isEditing
          ? _buildEditField()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show reasoning/thinking content if available
                if (!isUser && widget.message.hasReasoning)
                  _buildReasoningSection(),
                if (widget.isGenerating && widget.message.content.isEmpty)
                  const _TypingIndicator()
                else ...[
                  if (displayContent.isNotEmpty)
                    MessageContentWidget(
                      content: displayContent,
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
                  if (embeddedStatus != null && !widget.isGenerating)
                    MessageStatusBlockCard(
                      snapshot: embeddedStatus,
                      characterDisplayName:
                          widget.message.characterName?.trim() ?? '',
                    ),
                ],
                if (!isUser && !widget.isGenerating)
                  DataBankCitationPreview(
                    message: widget.message,
                  ),
                // Pictures + pending slots share one layout so size/position match.
                if (widget.message.hasAttachments || isPendingImageGen)
                  _buildMessageImages(),
              ],
            ),
    );

    final frostedBubble = ZephyrChatChrome.maybeFrosted(
      sigma: widget.frostOverBackground ? bubbleBlurSigma : 0,
      shape: bubbleShape,
      child: bubble,
    );
    // Clip when frost is off so edge-to-edge generated images follow bubble shape.
    final clippedBubble = isEdgeToEdgeGeneratedImage &&
            !(widget.frostOverBackground && bubbleBlurSigma > 0)
        ? ClipPath(
            clipper: ShapeBorderClipper(shape: bubbleShape),
            child: frostedBubble,
          )
        : frostedBubble;
    // Dedicated image bubbles stay compact instead of stretching full width.
    final sizedBubble = isSeparateGeneratedImageBubble
        ? Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _separateGeneratedImageMaxWidth,
              ),
              child: clippedBubble,
            ),
          )
        : clippedBubble;

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
          child: sizedBubble,
        ),
        if ((hasSwipes || widget.onQuickImagine != null) &&
            !widget.isGenerating)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSwipes) ...[
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
                if (widget.onQuickImagine != null)
                  ChromeIconButton(
                    key: const Key('message-quick-imagine'),
                    density: ChromeIconButtonDensity.compact,
                    tooltip: AppLocalizations.of(context).imagineFromLastReply,
                    icon: const Icon(Icons.photo_outlined, size: 20),
                    onPressed: widget.onQuickImagine,
                  ),
              ],
            ),
          ),
        if (!isUser && !widget.isGenerating && !widget.message.isGeneratedImage)
          ChatTTSMessageButton(
            text: widget.message.content,
            ownerId: widget.chatId,
            sourceId: widget.message.id,
            characterId: widget.message.characterId ?? widget.character?.id,
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
    final characterId = widget.character?.id ?? widget.message.characterId;
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
        onTap: () => context.openShell('/characters/$characterId'),
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

  static const double _separateGeneratedImageMaxWidth = 220;
  static const double _attachedImageStripHeight = 168;

  /// Attachments and pending image-gen slots in one shared layout.
  Widget _buildMessageImages() {
    final attachments = widget.message.attachments;
    final pendingCount = widget.message.isPendingImageGen
        ? widget.message.pendingImageGenCount
        : 0;
    final separateBubble = widget.message.isGeneratedImage &&
        !widget.message.isAttachedGeneratedImage &&
        widget.message.content.trim().isEmpty;

    if (separateBubble) {
      return _buildSeparateGeneratedImages(
        attachments: attachments,
        pendingCount: pendingCount,
      );
    }

    return _buildAttachedImageStrip(
      attachments,
      pendingCount: pendingCount,
      pendingAspect: widget.message.pendingImageGenAspect,
    );
  }

  /// Compact dedicated image bubble (completed and/or pending).
  Widget _buildSeparateGeneratedImages({
    required List<ChatAttachment> attachments,
    required int pendingCount,
  }) {
    final pendingAspect = widget.message.pendingImageGenAspect.clamp(0.55, 1.6);
    final tiles = <Widget>[
      for (var i = 0; i < attachments.length; i++)
        Builder(
          builder: (context) {
            final attachment = attachments[i];
            final aspect = (attachment.width != null &&
                    attachment.height != null &&
                    attachment.height! > 0)
                ? (attachment.width! / attachment.height!).clamp(0.55, 1.6)
                : pendingAspect;
            return GestureDetector(
              onTap: () => _showImagePreview(
                attachment,
                gallery: attachments,
                initialIndex: i,
              ),
              child: AspectRatio(
                aspectRatio: aspect,
                child: Image.file(
                  File(attachment.path),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.darkBackground,
                    child: const Icon(
                      Icons.broken_image,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      for (var i = 0; i < pendingCount; i++)
        AspectRatio(
          aspectRatio: pendingAspect,
          child: _buildPendingImageTile(compact: true),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tiles,
    );
  }

  Widget _buildPendingImageTile({bool compact = false}) {
    final genState = ref.watch(imageGenStateProvider);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final progress = genState.isGenerating && genState.progress > 0
        ? genState.progress
        : null;
    final percent = genState.isGenerating
        ? '${(genState.progress * 100).clamp(0, 100).round()}%'
        : l10n.generating;
    final indicatorSize = compact ? 22.0 : 28.0;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: indicatorSize,
                height: indicatorSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progress,
                ),
              ),
              SizedBox(height: compact ? 6 : 10),
              Text(
                percent,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: compact ? 11 : null,
                    ),
              ),
              if (genState.isGenerating) ...[
                SizedBox(height: compact ? 6 : 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: compact ? 3 : 4,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedImageStrip(
    List<ChatAttachment> attachments, {
    int pendingCount = 0,
    double pendingAspect = 1.0,
  }) {
    final radius = context.appChatBubbleCornerRadius;
    final hasTextAbove =
        widget.message.content.trim().isNotEmpty || widget.message.hasReasoning;
    const gap = 8.0;
    final topPad = hasTextAbove ? gap : 0.0;
    final totalCount = attachments.length + pendingCount;
    if (totalCount <= 0) return const SizedBox.shrink();

    double aspectFor(ChatAttachment? attachment) {
      if (attachment != null &&
          attachment.width != null &&
          attachment.height != null &&
          attachment.height! > 0) {
        return (attachment.width! / attachment.height!).clamp(0.55, 1.6);
      }
      return pendingAspect.clamp(0.55, 1.6);
    }

    Widget imageTile(ChatAttachment attachment, {required int index}) {
      return GestureDetector(
        onTap: () => _showImagePreview(
          attachment,
          gallery: attachments,
          initialIndex: index,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            File(attachment.path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppTheme.darkBackground,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    Widget slot({required int index}) {
      if (index < attachments.length) {
        return AspectRatio(
          aspectRatio: aspectFor(attachments[index]),
          child: imageTile(attachments[index], index: index),
        );
      }
      return AspectRatio(
        aspectRatio: aspectFor(null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: _buildPendingImageTile(compact: totalCount > 1),
        ),
      );
    }

    // Single slot: keep the padded full-width aspect tile.
    if (totalCount == 1) {
      return Padding(
        padding: EdgeInsets.only(top: topPad),
        child: slot(index: 0),
      );
    }

    // Multi: fixed-height strip so placeholders match finished tiles.
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: SizedBox(
        height: _attachedImageStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: totalCount,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemBuilder: (context, index) => slot(index: index),
        ),
      ),
    );
  }

  /// Show full-screen image preview (edge-to-edge on mobile).
  void _showImagePreview(
    ChatAttachment attachment, {
    List<ChatAttachment>? gallery,
    int initialIndex = 0,
  }) {
    final images = gallery ?? [attachment];
    final start = initialIndex.clamp(0, images.length - 1);
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenAttachmentViewer(
            attachments: images,
            initialIndex: start,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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

    showModalBottomSheet<void>(
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
                decoration: const BoxDecoration(
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

enum _FullscreenImageAction { save }

class _FullscreenAttachmentViewer extends StatefulWidget {
  const _FullscreenAttachmentViewer({
    required this.attachments,
    this.initialIndex = 0,
  });

  final List<ChatAttachment> attachments;
  final int initialIndex;

  @override
  State<_FullscreenAttachmentViewer> createState() =>
      _FullscreenAttachmentViewerState();
}

class _FullscreenAttachmentViewerState
    extends State<_FullscreenAttachmentViewer> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final PageController _pageController;
  late int _index;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.attachments.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.attachments.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final path = widget.attachments[i].path;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showImageActions(path),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: top + 4,
              right: 8,
              child: ChromeIconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.attachments.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: Text(
                  '${_index + 1}/${widget.attachments.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageActions(String imagePath) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final action = await showAdaptiveActionDrawer<_FullscreenImageAction>(
      context: context,
      actions: [
        AdaptiveActionDrawerItem(
          value: _FullscreenImageAction.save,
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.momentsSavePhoto),
        ),
      ],
    );
    if (action != _FullscreenImageAction.save || !mounted) return;
    await _saveImage(imagePath);
  }

  Future<void> _saveImage(String imagePath) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ImageSaveUtils.saveImage(imagePath);
      if (!mounted) return;
      _showFeedback(l10n.momentsPhotoSaved);
    } catch (_) {
      if (!mounted) return;
      _showFeedback(l10n.momentsPhotoSaveFailed);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  void _showFeedback(String message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Text(message),
        ),
      );
  }
}
