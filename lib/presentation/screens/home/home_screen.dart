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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: spacedAppBarActions([
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
        ]),
      ),
      body: const _ChatListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.characters),
        tooltip: l10n.newChat,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ChatListView extends ConsumerWidget {
  const _ChatListView();

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
            ElevatedButton(
              onPressed: () => ref.invalidate(pagedChatsProvider),
              child: Text(l10n.retry),
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
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.characters),
                  icon: const Icon(Icons.people),
                  label: Text(l10n.browseCharacters),
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
                return _ChatListTile(chat: chat);
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

  const _ChatListTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final characterAsync =
        ref.watch(_characterForChatProvider(chat.characterId));
    final groupPresentationAsync = chat.groupId == null
        ? null
        : ref.watch(_groupPresentationProvider(chat.groupId!));
    final lastMessageAsync = ref.watch(_lastMessageProvider(chat.id));

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: groupPresentationAsync != null
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
                error: (_, __) => const CircleAvatar(child: Icon(Icons.person)),
                data: _buildCharacterAvatar,
              ),
        title: groupPresentationAsync != null
            ? groupPresentationAsync.when(
                loading: () => Text(l10n.loading),
                error: (_, __) => Text(chat.title),
                data: (presentation) =>
                    Text(presentation?.group.name ?? chat.title),
              )
            : characterAsync.when(
                loading: () => Text(l10n.loading),
                error: (_, __) => Text(chat.title),
                data: (character) => Text(character?.name ?? chat.title),
              ),
        subtitle: lastMessageAsync.when(
          loading: () => const Text('...'),
          error: (_, __) => Text(l10n.noMessages),
          data: (message) => Text(
            message?.content ?? l10n.noMessagesYet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            AdaptiveActionMenuButton<String>(
              title: chat.title,
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => [
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
          // Navigate to chat screen
          context.push('/chat/${chat.id}');
        },
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
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
    }
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
