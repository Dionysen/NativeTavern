import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/group.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/chat_repository.dart';
import 'package:native_tavern/data/repositories/group_repository.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/theme/zephyr_chat_chrome.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/widgets/common/group_avatar.dart';
import 'package:native_tavern/presentation/utils/destructive_confirm.dart';
import 'package:native_tavern/presentation/widgets/common/adaptive_action_drawer.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

/// Home screen showing recent chats
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _selectionMode = false;
  final Set<String> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh chat list when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(pagedChatsProvider);
      ref.invalidate(_groupPresentationProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh chat list when returning to the app
      ref.invalidate(pagedChatsProvider);
      ref.invalidate(_groupPresentationProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh chat list whenever dependencies change (e.g., when navigating back)
    ref.invalidate(pagedChatsProvider);
    ref.invalidate(_groupPresentationProvider);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void _enterSelectionMode([String? chatId]) {
    setState(() {
      _selectionMode = true;
      _selectedChatIds.clear();
      if (chatId != null) {
        _selectedChatIds.add(chatId);
      }
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final count = _selectedChatIds.length;
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deleteSelectedChats,
      body: l10n.deleteSelectedChatsConfirmation(count),
    );
    if (!confirmed || !mounted) return;

    final repo = ref.read(chatRepositoryProvider);
    final ids = List<String>.from(_selectedChatIds);
    for (final id in ids) {
      await repo.deleteChat(id);
      ref.invalidate(_lastMessageProvider(id));
    }
    ref.invalidate(pagedChatsProvider);
    ref.invalidate(allChatsProvider);
    _exitSelectionMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.chatsDeletedCount(count))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selectionMode
              ? ChromeIconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.cancel,
                  onPressed: _exitSelectionMode,
                )
              : null,
          title: Text(
            _selectionMode
                ? l10n.chatsSelected(_selectedChatIds.length)
                : l10n.appTitle,
          ),
          actions: spacedAppBarActions([
            if (_selectionMode) ...[
              if (_selectedChatIds.isNotEmpty)
                ChromeIconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: _deleteSelectedChats,
                ),
              ChromeIconButton(
                icon: const Icon(Icons.check),
                tooltip: l10n.done,
                onPressed: _exitSelectionMode,
              ),
            ] else ...[
              ChromeIconButton(
                icon: const Icon(Icons.groups),
                tooltip: l10n.groupChats,
                onPressed: () => context.push(AppRoutes.groups),
              ),
              ChromeIconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: l10n.import,
                onPressed: () => context.push(AppRoutes.import_),
              ),
            ],
          ]),
        ),
        body: _ChatListView(
          selectionMode: _selectionMode,
          selectedIds: _selectedChatIds,
          onToggleSelect: _toggleChatSelection,
          onEnterSelection: _enterSelectionMode,
        ),
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton(
                onPressed: () => context.push(AppRoutes.characters),
                tooltip: l10n.newChat,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

class _ChatListView extends ConsumerWidget {
  const _ChatListView({
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onEnterSelection,
  });

  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatsAsync = ref.watch(pagedChatsProvider);

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.errorLoadingChats(error.toString())),
            const SizedBox(height: 16),
            ZephyrChatChrome.withComposerShadow(
              context: context,
              child: ElevatedButton(
                onPressed: () => ref.invalidate(pagedChatsProvider),
                child: Text(l10n.retry),
              ),
            ),
          ],
        ),
      ),
      data: (chats) {
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noChatsYet,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.startNewConversation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 24),
                ZephyrChatChrome.withComposerShadow(
                  context: context,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.characters),
                    icon: const Icon(Icons.people),
                    label: Text(l10n.browseCharacters),
                  ),
                ),
              ],
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 600) {
              ref.read(pagedChatsProvider.notifier).loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pagedChatsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _ChatListTile(
                  chat: chat,
                  selectionMode: selectionMode,
                  selected: selectedIds.contains(chat.id),
                  onToggleSelect: onToggleSelect,
                  onEnterSelection: onEnterSelection,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  final Chat chat;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onEnterSelection;

  const _ChatListTile({
    required this.chat,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onEnterSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final characterAsync =
        ref.watch(_characterForChatProvider(chat.characterId));
    final groupPresentationAsync = chat.groupId == null
        ? null
        : ref.watch(_groupPresentationProvider(chat.groupId!));
    final lastMessageAsync = ref.watch(_lastMessageProvider(chat.id));

    return Card(
      child: ListTile(
        selected: selectionMode && selected,
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: selectionMode
            ? Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? scheme.primary : scheme.outline,
              )
            : groupPresentationAsync != null
                ? groupPresentationAsync.when(
                    loading: () => const SizedBox.square(
                      dimension: 56,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const GroupAvatar(characters: []),
                    data: (presentation) => GroupAvatar(
                      characters: presentation?.characters ?? const [],
                    ),
                  )
                : characterAsync.when(
                    loading: () => const CircleAvatar(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) =>
                        const CircleAvatar(child: Icon(Icons.person)),
                    data: _buildCharacterAvatar,
                  ),
        title: groupPresentationAsync != null
            ? groupPresentationAsync.when(
                loading: () => _titleText(l10n.loading),
                error: (_, __) => _titleText(chat.title),
                data: (presentation) =>
                    _titleText(presentation?.group.name ?? chat.title),
              )
            : characterAsync.when(
                loading: () => _titleText(l10n.loading),
                error: (_, __) => _titleText(chat.title),
                data: (character) =>
                    _titleText(character?.name ?? chat.title),
              ),
        subtitle: lastMessageAsync.when(
          loading: () => _previewText(context, '...'),
          error: (_, __) => _previewText(context, l10n.noMessages),
          data: (message) => _previewText(
            context,
            message?.content ?? l10n.noMessagesYet,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(context, chat.updatedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            if (!selectionMode)
              AdaptiveActionMenuButton<String>(
                title: chat.title,
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  AdaptiveActionDrawerItem(
                    value: 'new_chat',
                    leading: const Icon(Icons.add_comment_outlined),
                    title: Text(l10n.newChat),
                  ),
                  AdaptiveActionDrawerItem(
                    value: 'delete',
                    leading: const Icon(Icons.delete),
                    title: Text(l10n.delete),
                    destructive: true,
                  ),
                ],
              ),
          ],
        ),
        onTap: () {
          if (selectionMode) {
            onToggleSelect(chat.id);
            return;
          }
          context.push('/chat/${chat.id}');
        },
        onLongPress: () {
          if (selectionMode) {
            onToggleSelect(chat.id);
          } else {
            onEnterSelection(chat.id);
          }
        },
      ),
    );
  }

  Widget _titleText(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _previewText(BuildContext context, String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
    );
  }

  Widget _buildCharacterAvatar(Character? character) {
    final avatarPath = character?.assets?.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CharacterAvatarCircle(
        imagePath: avatarPath,
        errorBuilder: (_, __, ___) => _characterFallback(character),
      );
    }
    return _characterFallback(character);
  }

  Widget _characterFallback(Character? character) {
    return CircleAvatar(
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
      child: Text(
        character?.name.isNotEmpty == true
            ? character!.name.characters.first.toUpperCase()
            : '?',
        style: const TextStyle(color: AppTheme.accentColor),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime dateTime) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return l10n.yesterday;
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else {
      // Show date
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'new_chat':
        unawaited(_startNewChatWithSameCard(context, ref));
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
    }
  }

  Future<void> _startNewChatWithSameCard(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(activeChatProvider.notifier);

    final String? newChatId;
    if (chat.groupId != null) {
      final group =
          await ref.read(groupRepositoryProvider).getGroup(chat.groupId!);
      if (group == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToCreateChat)),
          );
        }
        return;
      }
      newChatId = await notifier.createGroupChat(group);
    } else {
      newChatId = await notifier.createChat(chat.characterId);
    }

    if (!context.mounted) return;
    if (newChatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToCreateChat)),
      );
      return;
    }

    ref.invalidate(pagedChatsProvider);
    ref.invalidate(allChatsProvider);
    context.push('/chat/$newChatId');
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      ref,
      title: l10n.deleteChat,
      body: l10n.deleteChatConfirmation,
    );
    if (!confirmed) return;

    await ref.read(chatRepositoryProvider).deleteChat(chat.id);
    ref.invalidate(pagedChatsProvider);
    ref.invalidate(allChatsProvider);
    ref.invalidate(_lastMessageProvider(chat.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatDeleted)),
      );
    }
  }
}

/// Provider to get character for a chat
final _characterForChatProvider =
    FutureProvider.family((ref, String characterId) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(characterId);
});

class _GroupPresentation {
  const _GroupPresentation({required this.group, required this.characters});

  final Group group;
  final List<Character?> characters;
}

final _groupPresentationProvider =
    FutureProvider.family<_GroupPresentation?, String>((ref, groupId) async {
  final groupRepo = ref.watch(groupRepositoryProvider);
  final characterRepo = ref.watch(characterRepositoryProvider);
  final group = await groupRepo.getGroup(groupId);
  if (group == null) return null;
  final characters = await Future.wait(
    group.sortedMembers.take(4).map(
          (member) => characterRepo.getCharacter(member.characterId),
        ),
  );
  return _GroupPresentation(group: group, characters: characters);
});

/// Provider to get last message for a chat
final _lastMessageProvider = FutureProvider.family((ref, String chatId) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getLastMessage(chatId);
});
