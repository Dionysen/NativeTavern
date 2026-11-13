import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_tavern/core/app_scope.dart';
import 'package:native_tavern/core/utils/image_save_utils.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/moment/moment_post.dart';
import 'package:native_tavern/domain/services/moment_service.dart';
import 'package:native_tavern/presentation/screens/play/moments_palette.dart';
import 'package:native_tavern/domain/services/moments_cover_storage.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/data/models/persona.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/moment_providers.dart';
import 'package:native_tavern/presentation/providers/persona_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// WeChat Moments-style public feed. Browsing only; posting is a full page.
class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  static const _coverHeight = 286.0;
  static const _expandedCoverHeight = 460.0;
  static const _profileAvatarSize = 72.0;
  static const _profileOverlap = _profileAvatarSize / 2;
  static const _coverExpandDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final feed = ref.watch(pagedMomentFeedProvider);
    final characters =
        ref.watch(characterListProvider).asData?.value ?? const <Character>[];
    final persona = ref.watch(activePersonaProvider).asData?.value;
    final selfName = momentsPersonaName(persona, l10n.momentsAuthorMe);
    final palette = MomentsPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.cell,
        body: !settings.momentsEnabled
            ? Column(
                children: [
                  _DisabledCoverWithProfile(
                    coverHeight: _coverHeight,
                    topInset: topInset,
                    selfName: selfName,
                    selfAvatarPath: persona?.avatarPath,
                    palette: palette,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: _CenteredMessage(
                      l10n.momentsDisabledEmpty,
                      key: const Key('moments-disabled-empty'),
                      color: palette.time,
                    ),
                  ),
                ],
              )
            : feed.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _CenteredMessage(error.toString()),
                data: (items) {
                  final dataPath = ref.read(dataPathProvider);
                  final coverPath = persona?.id == null
                      ? null
                      : MomentsCoverStorage.existingCoverPathSync(
                          dataPath,
                          persona!.id,
                        );
                  return _MomentsEnabledFeed(
                    items: items,
                    characters: characters,
                    persona: persona,
                    selfName: selfName,
                    palette: palette,
                    topInset: topInset,
                    initialCoverPath: coverPath,
                    onCompose: () =>
                        context.openShell(AppRoutes.playMomentsCompose),
                  );
                },
              ),
      ),
    );
  }

  static Character? authorOf(List<Character> characters, MomentPost post) {
    if (post.origin != MomentPostOrigin.character) return null;
    for (final character in characters) {
      if (character.id == post.authorId) return character;
    }
    return null;
  }
}

class _MomentsEnabledFeed extends ConsumerStatefulWidget {
  const _MomentsEnabledFeed({
    required this.items,
    required this.characters,
    required this.persona,
    required this.selfName,
    required this.palette,
    required this.topInset,
    required this.initialCoverPath,
    required this.onCompose,
  });

  final List<MomentFeedItem> items;
  final List<Character> characters;
  final Persona? persona;
  final String selfName;
  final MomentsPalette palette;
  final double topInset;
  final String? initialCoverPath;
  final VoidCallback onCompose;

  @override
  ConsumerState<_MomentsEnabledFeed> createState() =>
      _MomentsEnabledFeedState();
}

class _MomentsEnabledFeedState extends ConsumerState<_MomentsEnabledFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coverExpandController;
  late final Animation<double> _coverExpandAnimation;
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  String? _coverImagePath;
  String? _loadedPersonaId;

  @override
  void initState() {
    super.initState();
    _coverExpandController = AnimationController(
      vsync: this,
      duration: MomentsScreen._coverExpandDuration,
    );
    _coverExpandAnimation = CurvedAnimation(
      parent: _coverExpandController,
      curve: Curves.easeInOut,
    );
    _coverExpandController.addListener(() => setState(() {}));
    _coverImagePath = widget.initialCoverPath;
    _loadedPersonaId = widget.persona?.id;
  }

  @override
  void didUpdateWidget(covariant _MomentsEnabledFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.persona?.id != widget.persona?.id ||
        oldWidget.initialCoverPath != widget.initialCoverPath) {
      _coverExpandController.reverse();
      _coverImagePath = widget.initialCoverPath;
      _loadedPersonaId = widget.persona?.id;
    }
  }

  @override
  void dispose() {
    _coverExpandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double get _collapsedHeaderHeight =>
      MomentsScreen._coverHeight +
      widget.topInset +
      MomentsScreen._profileOverlap;

  double get _expandedHeaderHeight =>
      MomentsScreen._expandedCoverHeight + widget.topInset;

  double get _headerHeight =>
      lerpDouble(
        _collapsedHeaderHeight,
        _expandedHeaderHeight,
        _coverExpandAnimation.value,
      ) ??
      _collapsedHeaderHeight;

  void _toggleCoverExpansion() {
    if (_coverExpandController.isAnimating) return;
    if (_coverExpandController.value == 0) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _coverExpandController.forward();
    } else {
      _coverExpandController.reverse();
    }
  }

  Future<void> _pickCoverImage() async {
    final personaId = widget.persona?.id;
    if (personaId == null) return;
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      final dataPath = ref.read(dataPathProvider);
      final path = await MomentsCoverStorage.saveCover(
        dataPath,
        personaId,
        image.path,
      );
      if (!mounted) return;
      setState(() => _coverImagePath = path);
    } catch (_) {
      // Gallery pick or copy failures are non-fatal; user can retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expandT = _coverExpandAnimation.value;
    final overlapHeight =
        lerpDouble(MomentsScreen._profileOverlap, 0, expandT) ?? 0;
    final profileOpacity = (1 - expandT).clamp(0.0, 1.0);
    final changeCoverOpacity = expandT.clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600) {
          ref.read(pagedMomentFeedProvider.notifier).loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: widget.palette.cell,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: widget.palette.text,
            title: Text(l10n.moments),
            expandedHeight: _headerHeight,
            toolbarHeight: kToolbarHeight,
            leading: ChromeIconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              ChromeIconButton(
                key: const Key('moments-compose'),
                tooltip: l10n.momentsCompose,
                onPressed: widget.onCompose,
                icon: const Icon(Icons.camera_alt_outlined),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          key: const Key('moments-cover-tap'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleCoverExpansion,
                          child: _CoverBackground.expandable(
                            imagePath: _loadedPersonaId == widget.persona?.id
                                ? _coverImagePath
                                : null,
                          ),
                        ),
                      ),
                      ColoredBox(
                        color: widget.palette.cell,
                        child: SizedBox(height: overlapHeight),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: profileOpacity < 0.05,
                      child: Opacity(
                        opacity: profileOpacity,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: _ProfileNameAndAvatar(
                            selfName: widget.selfName,
                            selfAvatarPath: widget.persona?.avatarPath,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: IgnorePointer(
                      ignoring: changeCoverOpacity < 0.5,
                      child: Opacity(
                        opacity: changeCoverOpacity,
                        child: TextButton(
                          key: const Key('moments-change-cover'),
                          style: TextButton.styleFrom(
                            foregroundColor: MomentsPalette.onMedia,
                            backgroundColor: MomentsPalette.mediaScrim,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _pickCoverImage,
                          child: Text(l10n.momentsChangeCover),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CenteredMessage(
                l10n.momentsEmpty,
                key: const Key('moments-empty'),
                color: widget.palette.time,
              ),
            )
          else
            SliverList.separated(
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.5,
                color: widget.palette.divider,
              ),
              itemBuilder: (context, index) => _MomentRow(
                item: widget.items[index],
                character: MomentsScreen.authorOf(
                  widget.characters,
                  widget.items[index].post,
                ),
                persona: widget.persona,
                selfName: widget.selfName,
                palette: widget.palette,
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground({required this.height})
      : expandable = false,
        imagePath = null;

  const _CoverBackground.expandable({this.imagePath})
      : height = 0,
        expandable = true;

  final double height;
  final bool expandable;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();
    final cover = DecoratedBox(
      decoration: BoxDecoration(
        gradient: hasImage ? null : MomentsPalette.coverGradient,
        image: hasImage
            ? DecorationImage(
                image: FileImage(File(imagePath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage ? null : CustomPaint(painter: _CoverGrainPainter()),
    );
    if (expandable) {
      return SizedBox(width: double.infinity, child: cover);
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: cover,
    );
  }
}

class _ProfileNameAndAvatar extends StatelessWidget {
  const _ProfileNameAndAvatar({
    required this.selfName,
    this.selfAvatarPath,
  });

  final String selfName;
  final String? selfAvatarPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: 10,
            bottom: MomentsScreen._profileOverlap + 6,
          ),
          child: Text(
            selfName,
            style: const TextStyle(
              color: MomentsPalette.onMedia,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: MomentsPalette.mediaShadow, blurRadius: 8),
              ],
            ),
          ),
        ),
        _SquareAvatar(
          name: selfName,
          size: MomentsScreen._profileAvatarSize,
          radius: 6,
          imagePath: selfAvatarPath,
          border: Border.all(color: MomentsPalette.onMedia, width: 1.5),
        ),
      ],
    );
  }
}

class _DisabledCoverWithProfile extends StatelessWidget {
  const _DisabledCoverWithProfile({
    required this.coverHeight,
    required this.topInset,
    required this.selfName,
    required this.palette,
    this.selfAvatarPath,
    this.onBack,
  });

  final double coverHeight;
  final double topInset;
  final String selfName;
  final String? selfAvatarPath;
  final MomentsPalette palette;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoverBackground(height: coverHeight + topInset),
            ColoredBox(
              color: palette.cell,
              child: const SizedBox(height: MomentsScreen._profileOverlap),
            ),
          ],
        ),
        Positioned(
          top: topInset + 4,
          left: 4,
          child: ChromeIconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: MomentsPalette.onMedia,
            ),
            onPressed: onBack,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: coverHeight + topInset - MomentsScreen._profileOverlap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _ProfileNameAndAvatar(
              selfName: selfName,
              selfAvatarPath: selfAvatarPath,
            ),
          ),
        ),
      ],
    );
  }
}

class _MomentRow extends ConsumerStatefulWidget {
  const _MomentRow({
    required this.item,
    required this.character,
    required this.persona,
    required this.selfName,
    required this.palette,
  });

  final MomentFeedItem item;
  final Character? character;
  final Persona? persona;
  final String selfName;
  final MomentsPalette palette;

  @override
  ConsumerState<_MomentRow> createState() => _MomentRowState();
}

class _MomentRowState extends ConsumerState<_MomentRow> {
  final _pendingComments = <MomentComment>[];

  void _openAuthor() {
    final post = widget.item.post;
    if (post.origin != MomentPostOrigin.character) return;
    context.openShell('/characters/${post.authorId}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final post = widget.item.post;
    final isSelf = post.origin == MomentPostOrigin.user;
    final name = isSelf ? widget.selfName : post.authorName;
    final knownIds = {
      for (final comment in widget.item.comments) comment.id,
    };
    final comments = [
      ...widget.item.comments,
      ..._pendingComments.where((comment) => !knownIds.contains(comment.id)),
    ];
    final palette = widget.palette;
    return Material(
      color: palette.cell,
      child: Padding(
        key: Key('moment-card-${post.id}'),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: isSelf ? null : Key('moment-author-${post.authorId}'),
              onTap: isSelf ? null : _openAuthor,
              child: _SquareAvatar(
                name: name,
                size: 42,
                radius: 4,
                imagePath: isSelf
                    ? widget.persona?.avatarPath
                    : widget.character?.assets?.avatarPath,
                imageUrl: isSelf ? null : widget.character?.assets?.avatarUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: isSelf ? null : _openAuthor,
                    child: Text(
                      name,
                      style: TextStyle(
                        color: palette.name,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (post.publicBody.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.publicBody,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (post.hasPhoto) ...[
                    const SizedBox(height: 8),
                    _MomentPhoto(
                      path: post.imagePath!,
                      photoKey: Key('moment-photo-${post.id}'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formatMomentTime(post.createdAt, l10n),
                        style: TextStyle(color: palette.time, fontSize: 13),
                      ),
                      const Spacer(),
                      _CommentButton(
                        post: post,
                        authorName: widget.selfName,
                        palette: palette,
                        onPosted: (comment) {
                          setState(() => _pendingComments.add(comment));
                        },
                      ),
                      const SizedBox(width: 8),
                      ChromeIconButton(
                        density: ChromeIconButtonDensity.compact,
                        key: Key('moment-like-${post.id}'),
                        tooltip: 'Like',
                        icon: Icon(
                          widget.item.likedByViewer
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 18,
                          color: widget.item.likedByViewer
                              ? MomentsPalette.liked
                              : palette.time,
                        ),
                        onPressed: () async {
                          await ref
                              .read(momentServiceProvider)
                              .toggleLike(post.id);
                          ref.invalidate(pagedMomentFeedProvider);
                        },
                      ),
                      if (widget.item.likeCount > 0)
                        Text(
                          '${widget.item.likeCount}',
                          style: TextStyle(color: palette.time, fontSize: 13),
                        ),
                    ],
                  ),
                  if (comments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _CommentBox(
                      postId: post.id,
                      comments: comments,
                      palette: palette,
                      onChanged: () {
                        ref.invalidate(pagedMomentFeedProvider);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentButton extends ConsumerWidget {
  const _CommentButton({
    required this.post,
    required this.authorName,
    required this.palette,
    required this.onPosted,
  });

  final MomentPost post;
  final String authorName;
  final MomentsPalette palette;
  final ValueChanged<MomentComment> onPosted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: palette.commentBox,
      borderRadius: BorderRadius.circular(3),
      child: InkWell(
        key: Key('moment-comment-${post.id}'),
        borderRadius: BorderRadius.circular(3),
        onTap: () => _promptComment(context, ref, l10n),
        child: SizedBox(
          width: 32,
          height: 20,
          child: Icon(Icons.more_horiz, size: 18, color: palette.name),
        ),
      ),
    );
  }

  Future<void> _promptComment(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !context.mounted) return;
    final origin = box.localToGlobal(Offset.zero);
    final selected = await showMenu<String>(
      context: context,
      color: MomentsPalette.menu,
      position: RelativeRect.fromLTRB(
        origin.dx - 88,
        origin.dy - 6,
        origin.dx,
        origin.dy + 28,
      ),
      items: [
        PopupMenuItem(
          value: 'comment',
          height: 36,
          child: Text(
            l10n.momentsComment,
            style: const TextStyle(
              color: MomentsPalette.onMedia,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
    if (selected != 'comment' || !context.mounted) return;
    await _editComment(context, ref, l10n);
  }

  Future<void> _editComment(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: palette.cell,
      builder: (sheetContext) => _MomentCommentComposerSheet(
        fieldKey: const Key('moment-comment-body'),
        hintText: l10n.momentsComment,
        sendLabel: l10n.send,
        backgroundColor: palette.cell,
      ),
    );
    if (body == null || body.isEmpty) return;
    final comment = await ref.read(momentServiceProvider).comment(
          postId: post.id,
          body: body,
          authorName: authorName,
        );
    onPosted(comment);
    ref.invalidate(pagedMomentFeedProvider);
  }
}

class _CommentBox extends StatelessWidget {
  const _CommentBox({
    required this.postId,
    required this.comments,
    required this.palette,
    required this.onChanged,
  });

  final String postId;
  final List<MomentComment> comments;
  final MomentsPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.commentBox,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final comment in comments)
              _CommentLine(
                postId: postId,
                comment: comment,
                palette: palette,
                onChanged: onChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentLine extends StatelessWidget {
  const _CommentLine({
    required this.postId,
    required this.comment,
    required this.palette,
    required this.onChanged,
  });

  final String postId;
  final MomentComment comment;
  final MomentsPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _reply(context),
      onLongPress: comment.authorId == MomentService.userAuthorId
          ? () => _delete(context)
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(
          TextSpan(
            children: [
              if (comment.parentCommentId != null) const TextSpan(text: '↳ '),
              TextSpan(
                text: comment.authorName,
                style: TextStyle(
                  color: palette.name,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '：${comment.body}',
                style: TextStyle(color: palette.text, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reply(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: palette.cell,
      builder: (sheetContext) => _MomentCommentComposerSheet(
        hintText: 'Reply to ${comment.authorName}',
        sendLabel: l10n.send,
        backgroundColor: palette.cell,
      ),
    );
    if (body == null || body.isEmpty || !context.mounted) return;
    await ProviderScope.containerOf(context, listen: false)
        .read(momentServiceProvider)
        .reply(postId: postId, parentCommentId: comment.id, body: body);
    onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('Delete your comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ProviderScope.containerOf(context, listen: false)
        .read(momentServiceProvider)
        .deleteComment(comment.id, authorId: MomentService.userAuthorId);
    onChanged();
  }
}

/// Owns the [TextEditingController] for the sheet lifetime so dispose does not
/// race the closing animation (avoids `_dependents.isEmpty` crashes).
class _MomentCommentComposerSheet extends StatefulWidget {
  const _MomentCommentComposerSheet({
    this.fieldKey,
    required this.hintText,
    required this.sendLabel,
    required this.backgroundColor,
  });

  final Key? fieldKey;
  final String hintText;
  final String sendLabel;
  final Color backgroundColor;

  @override
  State<_MomentCommentComposerSheet> createState() =>
      _MomentCommentComposerSheetState();
}

class _MomentCommentComposerSheetState
    extends State<_MomentCommentComposerSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: widget.backgroundColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: widget.fieldKey,
                    controller: _controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.hintText,
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submit,
                  child: Text(widget.sendLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MomentPhoto extends StatelessWidget {
  const _MomentPhoto({required this.path, required this.photoKey});

  final String path;
  final Key photoKey;

  @override
  Widget build(BuildContext context) {
    final image = File(path);
    if (!image.existsSync()) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => _openPreview(context, image),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 184, maxHeight: 184),
          child: Image.file(image, key: photoKey, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context, File image) {
    return showDialog<void>(
      context: context,
      barrierColor: MomentsPalette.viewer,
      builder: (_) => _MomentPhotoPreview(image: image),
    );
  }
}

class _MomentPhotoPreview extends StatefulWidget {
  const _MomentPhotoPreview({required this.image});

  final File image;

  @override
  State<_MomentPhotoPreview> createState() => _MomentPhotoPreviewState();
}

class _MomentPhotoPreviewState extends State<_MomentPhotoPreview> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: MomentsPalette.viewer,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          onLongPress: () => _showActions(context, l10n),
          child: Center(
            child: InteractiveViewer(
              child: Image.file(widget.image, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final save = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          key: const Key('moment-photo-save'),
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.momentsSavePhoto),
          onTap: () => Navigator.pop(sheetContext, true),
        ),
      ),
    );
    if (save != true || !context.mounted) return;
    try {
      await ImageSaveUtils.saveImage(widget.image.path);
      if (context.mounted) {
        _showFeedback(l10n.momentsPhotoSaved);
      }
    } catch (_) {
      if (context.mounted) {
        _showFeedback(l10n.momentsPhotoSaveFailed);
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

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({
    required this.name,
    required this.size,
    required this.radius,
    this.imagePath,
    this.imageUrl,
    this.border,
  });

  final String name;
  final double size;
  final double radius;
  final String? imagePath;
  final String? imageUrl;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    Widget child;
    final path = imagePath?.trim();
    final url = imageUrl?.trim();
    if (path != null && path.isNotEmpty) {
      child = CharacterAvatarImage(
        imagePath: path,
        errorBuilder: (_, __, ___) => _Initial(initial),
      );
    } else if (url != null && url.isNotEmpty) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Initial(initial),
      );
    } else {
      child = _Initial(initial);
    }
    // Border and clip must be separate layers or rounded corners look broken.
    final borderWidth = border is Border ? border!.top.width : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: border,
          color: MomentsPalette.avatarFill,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              (radius - borderWidth).clamp(0, radius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MomentsPalette.avatarInitial,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: MomentsPalette.onMedia,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 14),
        ),
      ),
    );
  }
}

class _CoverGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.08);
    for (var i = 0; i < 80; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        random.nextDouble() * 18 + 4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

@visibleForTesting
String formatMomentTime(DateTime createdAt, AppLocalizations l10n) {
  final now = DateTime.now();
  final local = createdAt.toLocal();
  final delta = now.difference(local);
  if (delta.inMinutes < 1) return l10n.justNow;
  if (delta.inHours < 1) {
    return l10n.minutesAgo(delta.inMinutes);
  }
  if (now.year == local.year &&
      now.month == local.month &&
      now.day == local.day) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (yesterday.year == local.year &&
      yesterday.month == local.month &&
      yesterday.day == local.day) {
    return l10n.yesterday;
  }
  return '${local.month}/${local.day}';
}
