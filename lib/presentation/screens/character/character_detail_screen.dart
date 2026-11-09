import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/core/utils/path_utils.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/domain/services/character_card_export_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/providers/moment_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/screens/import/import_screen.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/regex/character_regex_section.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

/// Character detail screen
class CharacterDetailScreen extends ConsumerWidget {
  final String characterId;

  const CharacterDetailScreen({
    super.key,
    required this.characterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final characterAsync = ref.watch(characterDetailProvider(characterId));

    return characterAsync.when(
      data: (character) {
        if (character == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.characterNotFound)),
            body: Center(
              child: Text(l10n.characterNotFoundMessage),
            ),
          );
        }
        return _CharacterDetailContent(character: character);
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(l10n.error)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${l10n.error}: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterDetailContent extends ConsumerStatefulWidget {
  final Character character;

  const _CharacterDetailContent({required this.character});

  @override
  ConsumerState<_CharacterDetailContent> createState() =>
      _CharacterDetailContentState();
}

class _CharacterDetailContentState
    extends ConsumerState<_CharacterDetailContent> {
  bool _isCreatingChat = false;

  /// Avatar height / width. Scroll-up from the resting hero reveals the full card.
  double? _avatarAspectRatio;
  final ScrollController _scrollController = ScrollController();

  /// True after we've jumped to the half-screen resting offset (or no jump needed).
  bool _heroResting = false;

  /// When false, [expandedHeight] stays at half-screen so the first paint matches
  /// the old crop. Flipped on just before jumping to the tall-hero offset.
  bool _fullHeroEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAvatarAspectRatio();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CharacterDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.assets?.avatarPath !=
        widget.character.assets?.avatarPath) {
      _avatarAspectRatio = null;
      _heroResting = false;
      _fullHeroEnabled = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _loadAvatarAspectRatio();
    }
  }

  Future<void> _loadAvatarAspectRatio() async {
    final path = widget.character.assets?.avatarPath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _heroResting = true);
      return;
    }
    try {
      final absolute = await PathUtils.toAbsolutePath(path);
      final bytes = await File(absolute).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final ratio = image.height / image.width;
      image.dispose();
      if (!mounted || ratio <= 0 || !ratio.isFinite) {
        if (mounted) setState(() => _heroResting = true);
        return;
      }
      setState(() {
        _avatarAspectRatio = ratio;
        _heroResting = false;
        _fullHeroEnabled = false;
      });
      _scheduleRestingJump();
    } catch (_) {
      if (mounted) setState(() => _heroResting = true);
    }
  }

  void _scheduleRestingJump() {
    var attempts = 0;
    void tryJump() {
      if (!mounted || _avatarAspectRatio == null) return;
      attempts++;

      final screen = MediaQuery.sizeOf(context);
      final restingHeight = screen.height * 0.5;
      final fullCardHeight = screen.width * _avatarAspectRatio!;
      if (fullCardHeight <= restingHeight) {
        // Card already fits in the half-screen hero — nothing to expand.
        if (!_heroResting) setState(() => _heroResting = true);
        return;
      }

      if (!_fullHeroEnabled) {
        // Expand to full-card height, then jump on the next frame once extent
        // has updated. A half-screen mask covers the one-frame offset-0 flash.
        setState(() => _fullHeroEnabled = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => tryJump());
        return;
      }

      if (_jumpToRestingHero()) {
        if (!_heroResting) setState(() => _heroResting = true);
        return;
      }
      // maxScrollExtent often lags the expandedHeight change by a few frames.
      if (attempts < 16) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryJump());
      } else if (!_heroResting) {
        setState(() => _heroResting = true);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryJump());
  }

  /// Jump so only the legacy half-screen hero is visible. Returns true when
  /// settled (or no jump needed); false when scroll extent is not ready yet.
  bool _jumpToRestingHero() {
    if (!_scrollController.hasClients ||
        _avatarAspectRatio == null ||
        !_fullHeroEnabled) {
      return false;
    }

    final screen = MediaQuery.sizeOf(context);
    final restingHeight = screen.height * 0.5;
    final fullCardHeight = screen.width * _avatarAspectRatio!;
    final expandedHeight =
        fullCardHeight < restingHeight ? restingHeight : fullCardHeight;
    final desired = expandedHeight - restingHeight;
    if (desired <= 0) return true;

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent + 0.5 < desired) return false;

    final target = desired.clamp(0.0, maxExtent);
    if ((_scrollController.offset - target).abs() > 0.5) {
      _scrollController.jumpTo(target);
    }
    return (_scrollController.offset - target).abs() <= 0.5;
  }

  Future<void> _startChat() async {
    if (_isCreatingChat) return;

    setState(() => _isCreatingChat = true);

    try {
      final chatId = await ref
          .read(activeChatProvider.notifier)
          .createChat(widget.character.id);

      if (chatId != null && mounted) {
        ref.invalidate(characterChatsProvider(widget.character.id));
        context.push('/chat/$chatId');
      } else if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToCreateChat)),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingChat = false);
      }
    }
  }

  Future<void> _handleMenuAction(String action, Character character) async {
    switch (action) {
      case 'delete':
        await _confirmDelete(character);
        break;
      case 'duplicate':
        await _duplicateCharacter(character);
        break;
      case 'export':
        await _exportCharacterCard(
          character,
          CharacterCardExportFormat.png,
        );
        break;
      case 'export_charx':
        await _exportCharacterCard(
          character,
          CharacterCardExportFormat.charx,
        );
        break;
    }
  }

  Future<void> _exportCharacterCard(
    Character character,
    CharacterCardExportFormat format,
  ) async {
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      final importService = ref.read(importServiceProvider);
      final exporter = CharacterCardExportService(importService);
      final path = await exporter.export(
        character,
        format,
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      if (path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.characterCardExported)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed('$e'))),
      );
    }
  }

  Future<void> _confirmDelete(Character character) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deleteCharacter,
      body: l10n.deleteCharacterConfirmationSimple(character.name),
    );

    if (confirmed && mounted) {
      try {
        // Use characterListProvider.notifier to ensure list gets refreshed
        await ref
            .read(characterListProvider.notifier)
            .deleteCharacter(character.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.characterDeleted)),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToDelete(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _duplicateCharacter(Character character) async {
    final l10n = AppLocalizations.of(context);
    try {
      final repo = ref.read(characterRepositoryProvider);
      final newCharacter = character.copyWith(
        id: '',
        name: '${character.name} (copy)',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      await repo.createCharacter(newCharacter);
      ref.invalidate(characterListProvider);
      ref.invalidate(characterFoldersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.characterDuplicated(character.name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDuplicate(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final character = widget.character;
    final screen = MediaQuery.sizeOf(context);
    // Keep expandedHeight at half-screen until [_fullHeroEnabled], then jump to
    // a resting offset so scroll-up can reveal the full card without a flash.
    final restingHeight = screen.height * 0.5;
    final fullCardHeight = _avatarAspectRatio == null
        ? restingHeight
        : screen.width * _avatarAspectRatio!;
    final expandedHeight = !_fullHeroEnabled || _avatarAspectRatio == null
        ? restingHeight
        : (fullCardHeight < restingHeight ? restingHeight : fullCardHeight);

    // Covers the one frame where the tall hero is at offset 0 before the jump.
    final showRestingMask = _fullHeroEnabled && !_heroResting;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                expandedHeight: expandedHeight,
                pinned: true,
                stretch: true,
                automaticallyImplyLeading:
                    !ThreePaneScope.isActive(context),
                // Collapsed toolbar title: AppBar lays this out between leading
                // and actions, so it never overlaps Live2D / edit / overflow.
                centerTitle: true,
                title: _CharacterDetailAppBarTitle(
                  name: character.name,
                  collapsed: true,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  // No zoomBackground: expanding must reveal more of the card.
                  stretchModes: const [
                    StretchMode.fadeTitle,
                  ],
                  centerTitle: true,
                  titlePadding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                  // Expanded hero title: may wrap; fades out as the bar collapses.
                  title: _CharacterDetailAppBarTitle(
                    name: character.name,
                    collapsed: false,
                  ),
                  background: _buildAvatarBackground(
                    character,
                    scheme,
                    restingHeight: restingHeight,
                    fullCardHeight: fullCardHeight,
                  ),
                ),
                actions: spacedAppBarActions([
                  ChromeIconButton(
                    density: ChromeIconButtonDensity.compact,
                    icon: const Icon(Icons.animation),
                    tooltip: 'Live2D',
                    onPressed: () =>
                        context.push('/characters/${character.id}/live2d'),
                  ),
                  ChromeIconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        context.push('/characters/${character.id}/edit'),
                  ),
                  AdaptiveActionMenuButton<String>(
                    title: character.name,
                    onSelected: (value) =>
                        _handleMenuAction(value, character),
                    itemBuilder: (context) => [
                      AdaptiveActionDrawerItem(
                        value: 'export',
                        title: Text(l10n.exportAsPng),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'export_charx',
                        title: Text(l10n.exportAsCharx),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'duplicate',
                        title: Text(l10n.duplicate),
                      ),
                      AdaptiveActionDrawerItem(
                        value: 'delete',
                        title: Text(l10n.delete),
                        destructive: true,
                        showDividerAbove: true,
                      ),
                    ],
                  ),
                ]),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Tags
                  if (character.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: character.tags
                          .map(
                            (tag) => Chip(
                              label: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                              backgroundColor: scheme.secondaryContainer,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                  if (character.tags.isNotEmpty) const SizedBox(height: 16),

                  // Creator info
                  Row(
                    children: [
                      if (character.creator.isNotEmpty) ...[
                        Icon(Icons.person_outline,
                            size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          l10n.byCreator(character.creator),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (character.version.isNotEmpty) ...[
                        Icon(Icons.update,
                            size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          l10n.versionLabel(character.version),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  _CharacterWorldRuntimeTile(characterId: character.id),
                  const SizedBox(height: 16),

                  _CharacterChatList(
                    characterId: character.id,
                    onStartChat: _isCreatingChat ? null : _startChat,
                  ),
                  const SizedBox(height: 16),
                  _CharacterFriendsList(characterId: character.id),
                  const SizedBox(height: 16),
                  CharacterRegexSection(characterId: character.id),
                  const SizedBox(height: 16),

                  // Description section
                  if (character.description.isNotEmpty)
                    _SectionCard(
                      title: l10n.description,
                      content: character.description,
                      icon: Icons.description,
                    ),
                  if (character.description.isNotEmpty)
                    const SizedBox(height: 16),

                  // Personality section
                  if (character.personality.isNotEmpty)
                    _SectionCard(
                      title: l10n.personality,
                      content: character.personality,
                      icon: Icons.psychology,
                    ),
                  if (character.personality.isNotEmpty)
                    const SizedBox(height: 16),

                  // Scenario section
                  if (character.scenario.isNotEmpty)
                    _SectionCard(
                      title: l10n.scenario,
                      content: character.scenario,
                      icon: Icons.movie,
                    ),
                  if (character.scenario.isNotEmpty) const SizedBox(height: 16),

                  // First message section
                  if (character.firstMessage.isNotEmpty)
                    _SectionCard(
                      title: l10n.firstMessage,
                      content: character.firstMessage,
                      icon: Icons.chat_bubble,
                    ),
                  if (character.firstMessage.isNotEmpty)
                    const SizedBox(height: 16),

                  // Alternate greetings section
                  if (character.alternateGreetings.isNotEmpty) ...[
                    _AlternateGreetingsCard(
                      greetings: character.alternateGreetings,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Example messages section
                  if (character.exampleMessages.isNotEmpty)
                    _SectionCard(
                      title: l10n.exampleMessages,
                      content: character.exampleMessages,
                      icon: Icons.format_quote,
                    ),
                  if (character.exampleMessages.isNotEmpty)
                    const SizedBox(height: 16),

                  // System prompt section
                  if (character.systemPrompt.isNotEmpty)
                    _SectionCard(
                      title: l10n.systemPrompt,
                      content: character.systemPrompt,
                      icon: Icons.settings_suggest,
                    ),
                  if (character.systemPrompt.isNotEmpty)
                    const SizedBox(height: 16),

                  // Post-history instructions section
                  if (character.postHistoryInstructions.isNotEmpty)
                    _SectionCard(
                      title: l10n.postHistoryInstructions,
                      content: character.postHistoryInstructions,
                      icon: Icons.rule,
                    ),
                  if (character.postHistoryInstructions.isNotEmpty)
                    const SizedBox(height: 16),

                  // Creator notes section
                  if (character.creatorNotes.isNotEmpty)
                    _SectionCard(
                      title: l10n.creatorNotes,
                      content: character.creatorNotes,
                      icon: Icons.note,
                    ),
                  if (character.creatorNotes.isNotEmpty)
                    const SizedBox(height: 16),

                  // Embedded Lorebook section
                  if (character.characterBook != null &&
                      character.characterBook!.entries.isNotEmpty)
                    _CharacterBookCard(
                      characterBook: character.characterBook!,
                    ),
                  if (character.characterBook != null &&
                      character.characterBook!.entries.isNotEmpty)
                    const SizedBox(height: 16),

                  const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showRestingMask)
            Positioned.fill(
              child: ColoredBox(
                color: scheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: restingHeight,
                      child: character.assets?.avatarPath != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CharacterAvatarImage(
                                  imagePath: character.assets!.avatarPath!,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (_, __, ___) =>
                                      _defaultBackground(scheme),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        scheme.surface.withValues(alpha: 0.85),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _defaultBackground(scheme),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCreatingChat ? null : _startChat,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        tooltip: l10n.startChat,
        child: _isCreatingChat
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildAvatarBackground(
    Character character,
    ColorScheme scheme, {
    required double restingHeight,
    required double fullCardHeight,
  }) {
    if (character.assets?.avatarPath != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // While the hero is near its resting size, keep cover crop. Once the
          // user overscrolls enough to approach the full card height, switch to
          // fitWidth so the complete artwork is visible.
          final showFullCard = constraints.maxHeight >=
              (fullCardHeight < restingHeight
                  ? restingHeight
                  : fullCardHeight * 0.92);
          return Stack(
            fit: StackFit.expand,
            children: [
              CharacterAvatarImage(
                imagePath: character.assets!.avatarPath!,
                fit: showFullCard ? BoxFit.fitWidth : BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => _defaultBackground(scheme),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      scheme.surface.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    return _defaultBackground(scheme);
  }

  Widget _defaultBackground(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.person,
          size: 120,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Character name for the detail [SliverAppBar].
///
/// [collapsed] true → single-line toolbar title (opacity rises as the bar
/// pins). false → expanded FlexibleSpaceBar title that may wrap (opacity
/// falls as the bar pins).
class _CharacterDetailAppBarTitle extends StatelessWidget {
  const _CharacterDetailAppBarTitle({
    required this.name,
    required this.collapsed,
  });

  final String name;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final double t;
    if (settings == null) {
      t = collapsed ? 1.0 : 0.0;
    } else {
      final delta = settings.maxExtent - settings.minExtent;
      t = delta <= 0
          ? 1.0
          : (1.0 - (settings.currentExtent - settings.minExtent) / delta)
              .clamp(0.0, 1.0);
    }

    // Cross-fade once the bar is mostly pinned so the expanded wrap title
    // does not linger inside the toolbar row.
    final pinnedFade =
        const Interval(0.55, 1.0, curve: Curves.easeInOut).transform(t);
    final opacity = collapsed ? pinnedFade : 1.0 - pinnedFade;

    if (opacity <= 0.0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Text(
      name,
      maxLines: collapsed ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      softWrap: !collapsed,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: scheme.onSurface,
        shadows: collapsed
            ? null
            : const [Shadow(color: Colors.black54, blurRadius: 4)],
      ),
    );

    return Opacity(opacity: opacity, child: text);
  }
}

/// Collapsed preview for long character fields / lorebook bodies.
///
/// Expand/collapse is owned by the parent so the toggle can sit beside copy
/// in the section header.
class _ExpandablePreviewText extends StatefulWidget {
  const _ExpandablePreviewText({
    required this.text,
    required this.expanded,
    this.style,
    this.onOverflowChanged,
  });

  static const int previewLines = 3;

  final String text;
  final bool expanded;
  final TextStyle? style;
  final ValueChanged<bool>? onOverflowChanged;

  @override
  State<_ExpandablePreviewText> createState() => _ExpandablePreviewTextState();
}

class _ExpandablePreviewTextState extends State<_ExpandablePreviewText> {
  bool? _exceedsPreview;

  @override
  void didUpdateWidget(covariant _ExpandablePreviewText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _exceedsPreview = null;
    }
  }

  void _measureIfNeeded(double maxWidth, TextStyle style) {
    if (_exceedsPreview != null || maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: _ExpandablePreviewText.previewLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    final exceeds = painter.didExceedMaxLines;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _exceedsPreview == exceeds) return;
      setState(() => _exceedsPreview = exceeds);
      widget.onOverflowChanged?.call(exceeds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    return LayoutBuilder(
      builder: (context, constraints) {
        _measureIfNeeded(constraints.maxWidth, style);
        return Text(
          widget.text,
          style: style,
          maxLines: widget.expanded ? null : _ExpandablePreviewText.previewLines,
          overflow:
              widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        );
      },
    );
  }
}

Widget _expandToggleButton({
  required BuildContext context,
  required bool expanded,
  required bool visible,
  required VoidCallback onPressed,
  double iconSize = 18,
}) {
  if (!visible) return const SizedBox.shrink();
  final l10n = AppLocalizations.of(context);
  return ChromeIconButton(
    density: ChromeIconButtonDensity.compact,
    icon: Icon(
      expanded ? Icons.expand_less : Icons.expand_more,
      size: iconSize,
    ),
    onPressed: onPressed,
    tooltip: expanded ? l10n.showLess : l10n.showMore,
  );
}

class _SectionCard extends StatefulWidget {
  final String title;
  final String content;
  final IconData icon;

  const _SectionCard({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;
  bool _canExpand = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.content));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.copiedToClipboard}: ${widget.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: _copyToClipboard,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ),
                  ChromeIconButton(
                    density: ChromeIconButtonDensity.compact,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: _copyToClipboard,
                    tooltip: l10n.copiedToClipboard,
                  ),
                  _expandToggleButton(
                    context: context,
                    expanded: _expanded,
                    visible: _canExpand,
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ExpandablePreviewText(
                text: widget.content,
                expanded: _expanded,
                onOverflowChanged: (exceeds) {
                  if (_canExpand == exceeds) return;
                  setState(() => _canExpand = exceeds);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlternateGreetingsCard extends StatelessWidget {
  final List<String> greetings;

  const _AlternateGreetingsCard({required this.greetings});

  void _copyGreeting(BuildContext context, String greeting, int index) {
    Clipboard.setData(ClipboardData(text: greeting));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${l10n.copiedToClipboard}: ${l10n.greetingNumber(index + 1)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAllGreetings(BuildContext context) {
    final allText = greetings
        .asMap()
        .entries
        .map((e) => '--- Greeting ${e.key + 1} ---\n${e.value}')
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: allText));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${l10n.copiedToClipboard}: ${l10n.alternateGreetingsCount(greetings.length)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waving_hand, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.alternateGreetingsCount(greetings.length),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                  ),
                ),
                ChromeIconButton(
                  icon: const Icon(Icons.copy_all, size: 18),
                  onPressed: () => _copyAllGreetings(context),
                  tooltip: l10n.copiedToClipboard,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...greetings.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExpandableGreetingTile(
                      index: entry.key,
                      greeting: entry.value,
                      onCopy: () =>
                          _copyGreeting(context, entry.value, entry.key),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableGreetingTile extends StatefulWidget {
  const _ExpandableGreetingTile({
    required this.index,
    required this.greeting,
    required this.onCopy,
  });

  final int index;
  final String greeting;
  final VoidCallback onCopy;

  @override
  State<_ExpandableGreetingTile> createState() =>
      _ExpandableGreetingTileState();
}

class _ExpandableGreetingTileState extends State<_ExpandableGreetingTile> {
  bool _expanded = false;
  bool _canExpand = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: widget.onCopy,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.greetingNumber(widget.index + 1),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  icon: const Icon(Icons.copy, size: 14),
                  onPressed: widget.onCopy,
                  tooltip: l10n.copiedToClipboard,
                ),
                _expandToggleButton(
                  context: context,
                  expanded: _expanded,
                  visible: _canExpand,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  iconSize: 14,
                ),
              ],
            ),
            const SizedBox(height: 4),
            _ExpandablePreviewText(
              text: widget.greeting,
              expanded: _expanded,
              onOverflowChanged: (exceeds) {
                if (_canExpand == exceeds) return;
                setState(() => _canExpand = exceeds);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterBookCard extends StatelessWidget {
  final CharacterBook characterBook;

  const _CharacterBookCard({required this.characterBook});

  void _copyEntry(BuildContext context, CharacterBookEntry entry) {
    final text =
        'Name: ${entry.name}\nKeys: ${entry.keys.join(", ")}\nContent: ${entry.content}';
    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${l10n.copiedToClipboard}: ${entry.name.isNotEmpty ? entry.name : entry.keys.join(", ")}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabledEntries = characterBook.entries.where((e) => e.enabled).length;
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, size: 20, color: scheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        characterBook.name ?? l10n.embeddedLorebook,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.tertiary,
                                ),
                      ),
                      Text(
                        l10n.entriesEnabled(
                            enabledEntries, characterBook.entries.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (characterBook.description != null &&
                characterBook.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ExpandableBookDescription(
                text: characterBook.description!,
                style: bodyStyle,
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...characterBook.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExpandableBookEntryTile(
                  entry: entry,
                  bodyStyle: bodyStyle,
                  onCopy: () => _copyEntry(context, entry),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableBookDescription extends StatefulWidget {
  const _ExpandableBookDescription({
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<_ExpandableBookDescription> createState() =>
      _ExpandableBookDescriptionState();
}

class _ExpandableBookDescriptionState
    extends State<_ExpandableBookDescription> {
  bool _expanded = false;
  bool _canExpand = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_canExpand)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _expandToggleButton(
              context: context,
              expanded: _expanded,
              visible: true,
              onPressed: () => setState(() => _expanded = !_expanded),
              iconSize: 14,
            ),
          ),
        _ExpandablePreviewText(
          text: widget.text,
          style: widget.style,
          expanded: _expanded,
          onOverflowChanged: (exceeds) {
            if (_canExpand == exceeds) return;
            setState(() => _canExpand = exceeds);
          },
        ),
      ],
    );
  }
}

class _ExpandableBookEntryTile extends StatefulWidget {
  const _ExpandableBookEntryTile({
    required this.entry,
    required this.onCopy,
    this.bodyStyle,
  });

  final CharacterBookEntry entry;
  final VoidCallback onCopy;
  final TextStyle? bodyStyle;

  @override
  State<_ExpandableBookEntryTile> createState() =>
      _ExpandableBookEntryTileState();
}

class _ExpandableBookEntryTileState extends State<_ExpandableBookEntryTile> {
  bool _expanded = false;
  bool _canExpand = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    return GestureDetector(
      onLongPress: widget.onCopy,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: entry.enabled
              ? scheme.surfaceContainerHigh
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: entry.enabled
                ? scheme.tertiary.withValues(alpha: 0.35)
                : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.enabled ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: entry.enabled
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.name.isNotEmpty
                        ? entry.name
                        : entry.keys.join(', '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: entry.enabled
                              ? null
                              : scheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ChromeIconButton(
                  density: ChromeIconButtonDensity.compact,
                  icon: const Icon(Icons.copy, size: 14),
                  onPressed: widget.onCopy,
                  tooltip: l10n.copiedToClipboard,
                ),
                if (entry.content.isNotEmpty)
                  _expandToggleButton(
                    context: context,
                    expanded: _expanded,
                    visible: _canExpand,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    iconSize: 14,
                  ),
              ],
            ),
            if (entry.keys.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: entry.keys
                    .map(
                      (key) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          key,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                  ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (entry.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ExpandablePreviewText(
                text: entry.content,
                style: widget.bodyStyle,
                expanded: _expanded,
                onOverflowChanged: (exceeds) {
                  if (_canExpand == exceeds) return;
                  setState(() => _canExpand = exceeds);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CharacterFriendsList extends ConsumerWidget {
  const _CharacterFriendsList({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: ref.watch(characterSocialServiceProvider).friendsOf(characterId),
      builder: (context, snapshot) {
        final friends = snapshot.data ?? const [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 20, color: scheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.momentsFriends,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: Text(
                      l10n.momentsNoFriends,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  for (final friend in friends)
                    ListTile(
                      dense: true,
                      title: Text(friend.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/characters/${friend.id}'),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CharacterWorldRuntimeTile extends ConsumerWidget {
  const _CharacterWorldRuntimeTile({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final momentsOn = ref.watch(appSettingsProvider).momentsEnabled;
    final enabledAsync =
        ref.watch(characterWorldRuntimeEnabledProvider(characterId));
    final enabled = enabledAsync.valueOrNull ?? false;

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.public_outlined),
        title: Text(l10n.characterWorldRuntimeEnabled),
        subtitle: Text(l10n.characterWorldRuntimeEnabledHint),
        value: enabled,
        onChanged: !momentsOn
            ? null
            : (value) async {
                await ref
                    .read(worldRuntimeProvider)
                    .setCharacterEnabled(characterId, value);
                ref
                    .read(worldRuntimeMembershipRevisionProvider.notifier)
                    .state++;
              },
      ),
    );
  }
}

class _CharacterChatList extends ConsumerWidget {
  const _CharacterChatList({
    required this.characterId,
    required this.onStartChat,
  });

  final String characterId;
  final VoidCallback? onStartChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chats = ref.watch(characterChatsProvider(characterId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.chats,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onStartChat,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.newChat),
                  ),
                ],
              ),
            ),
            chats.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$error'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: Text(
                      l10n.noChatsYet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final chat in items)
                      ListTile(
                        dense: true,
                        title: Text(
                          chat.title.trim().isEmpty ? l10n.chats : chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatChatTime(chat.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/chat/${chat.id}'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatChatTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
