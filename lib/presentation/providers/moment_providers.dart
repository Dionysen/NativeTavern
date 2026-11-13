import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/core/app_scope.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/moment/moment_post.dart';
import 'package:native_tavern/data/repositories/character_friendship_repository.dart';
import 'package:native_tavern/data/repositories/operation_log_repository.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/chat_repository.dart';
import 'package:native_tavern/data/repositories/drift_moment_repository.dart';
import 'package:native_tavern/data/repositories/group_repository.dart';
import 'package:native_tavern/data/repositories/world_info_repository.dart';
import 'package:native_tavern/domain/repositories/moment_repository.dart';
import 'package:native_tavern/domain/services/character_social_service.dart';
import 'package:native_tavern/domain/services/chat_generation_pipeline.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern/domain/services/moment_context_contributor.dart';
import 'package:native_tavern/domain/services/moment_service.dart';
import 'package:native_tavern/domain/services/world_runtime.dart';
import 'package:native_tavern/presentation/providers/chat_extension_providers.dart';
import 'package:native_tavern/presentation/providers/data_bank_providers.dart';
import 'package:native_tavern/presentation/providers/image_gen_providers.dart';
import 'package:native_tavern/presentation/providers/memory_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/providers/story_providers.dart';
import 'package:native_tavern/presentation/providers/story_timeline_providers.dart';

final momentRepositoryProvider = Provider<MomentRepository>((ref) {
  return DriftMomentRepository(ref.watch(databaseProvider));
});

final characterFriendshipRepositoryProvider =
    Provider<CharacterFriendshipRepository>((ref) {
  return CharacterFriendshipRepository(ref.watch(databaseProvider));
});

final characterSocialServiceProvider = Provider<CharacterSocialService>((ref) {
  return CharacterSocialService(
    friendships: ref.watch(characterFriendshipRepositoryProvider),
    groups: ref.watch(groupRepositoryProvider),
    characters: ref.watch(characterRepositoryProvider),
  );
});

final operationLogRepositoryProvider = Provider<OperationLogRepository>((ref) {
  return OperationLogRepository(ref.watch(databaseProvider));
});

final momentServiceProvider = Provider<MomentService>((ref) {
  return MomentService(
    momentRepository: ref.watch(momentRepositoryProvider),
    characterRepository: ref.watch(characterRepositoryProvider),
    chatRepository: ref.watch(chatRepositoryProvider),
    worldInfoRepository: ref.watch(worldInfoRepositoryProvider),
    dataBank: ref.watch(dataBankRepositoryProvider),
    social: ref.watch(characterSocialServiceProvider),
    operations: ref.watch(operationLogRepositoryProvider),
    memories: ref.watch(longTermMemoryRepositoryProvider),
    dataPath: ref.watch(dataPathProvider),
    transport: (messages, config) {
      return ref.read(llmServiceProvider).generate(messages, config);
    },
    imageGenerator: (prompt) async {
      final imageSettings = ref.read(imageGenSettingsProvider);
      if (!imageSettings.enabled) return null;
      final imageService = ref.read(imageGenServiceProvider);
      imageService.updateSettings(imageSettings);
      final result = await imageService.generate(
        ImageGenRequest(
          prompt: prompt,
          negativePrompt: imageSettings.defaultNegativePrompt,
          width: imageSettings.defaultWidth,
          height: imageSettings.defaultHeight,
          steps: imageSettings.defaultSteps,
          cfgScale: imageSettings.defaultCfgScale,
          sampler: imageSettings.defaultSampler,
          scheduler: imageSettings.defaultScheduler,
        ),
      );
      if (result == null || result.images.isEmpty) return null;
      return result.images.first;
    },
  );
});

final momentContextContributorProvider =
    Provider<MomentContextContributor>((ref) {
  return MomentContextContributor(
    moments: ref.watch(momentServiceProvider),
    enabled: () => ref.read(appSettingsProvider).momentsEnabled,
    chatEnabled: (chatId) async {
      final chat = await ref.read(chatRepositoryProvider).getChat(chatId);
      return chat?.momentsInChat == true;
    },
  );
});

final momentContextRegistrationProvider =
    Provider<ChatExtensionRegistration>((ref) {
  final registration = ref
      .watch(chatExtensionRegistryProvider)
      .registerContributor(ref.watch(momentContextContributorProvider));
  ref.onDispose(registration.dispose);
  return registration;
});

final worldMomentRevisionProvider = StateProvider<int>((ref) => 0);

/// Bumps when a character is opted into / out of the world loop.
final worldRuntimeMembershipRevisionProvider = StateProvider<int>((ref) => 0);

final worldRuntimeProvider = Provider<WorldRuntime>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final runtime = WorldRuntime(
    momentService: ref.watch(momentServiceProvider),
    characterRepository: ref.watch(characterRepositoryProvider),
    social: ref.watch(characterSocialServiceProvider),
    story: ref.watch(storyServiceProvider),
    operations: ref.watch(operationLogRepositoryProvider),
    store: FileWorldWakeStore(ref.watch(dataPathProvider)),
    enabled: () => ref.read(appSettingsProvider).momentsEnabled,
    storyEnabled: () => ref.read(appSettingsProvider).storyEnabled,
    config: () => ref.read(llmConfigProvider),
    onPublished: (_) {
      ref.read(worldMomentRevisionProvider.notifier).state++;
    },
    onStoryChanged: () {
      ref.read(storyRevisionProvider.notifier).state++;
    },
  );
  if (settings.momentsEnabled || settings.storyEnabled) {
    runtime.start();
  }
  ref.onDispose(runtime.dispose);
  return runtime;
});

final characterWorldRuntimeEnabledProvider =
    FutureProvider.family<bool, String>((ref, characterId) async {
  ref.watch(worldRuntimeMembershipRevisionProvider);
  return ref.watch(worldRuntimeProvider).isCharacterEnabled(characterId);
});

final momentFeedProvider =
    FutureProvider.autoDispose<List<MomentFeedItem>>((ref) async {
  if (!ref.watch(appSettingsProvider).momentsEnabled) return const [];
  ref.watch(worldMomentRevisionProvider);
  return ref.watch(momentServiceProvider).loadFeed();
});

class PagedMomentFeedState {
  const PagedMomentFeedState({
    this.items = const [],
    this.initialLoading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<MomentFeedItem> items;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
}

/// Paginated feed used by the moments screen. The shell renders immediately;
/// [PagedMomentFeedState.initialLoading] tracks the first page fetch.
final pagedMomentFeedProvider =
    NotifierProvider.autoDispose<PagedMomentFeedNotifier, PagedMomentFeedState>(
  PagedMomentFeedNotifier.new,
);

class PagedMomentFeedNotifier extends AutoDisposeNotifier<PagedMomentFeedState> {
  static const _pageSize = 24;
  int _offset = 0;
  bool _loadScheduled = false;
  bool _maintenanceScheduled = false;
  List<MomentFeedItem> _retainedItems = const [];
  bool _retainedHasMore = true;

  @override
  PagedMomentFeedState build() {
    ref.watch(worldMomentRevisionProvider);
    if (!ref.watch(appSettingsProvider.select((s) => s.momentsEnabled))) {
      _retainedItems = const [];
      _retainedHasMore = true;
      _offset = 0;
      return const PagedMomentFeedState();
    }
    _loadScheduled = false;
    _scheduleInitialLoad();
    if (_retainedItems.isNotEmpty) {
      return PagedMomentFeedState(
        items: _retainedItems,
        hasMore: _retainedHasMore,
      );
    }
    return const PagedMomentFeedState(initialLoading: true);
  }

  void _commit(PagedMomentFeedState next) {
    if (next.items.isNotEmpty) {
      _retainedItems = next.items;
      _retainedHasMore = next.hasMore;
    }
    state = next;
  }

  void _scheduleInitialLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    scheduleMicrotask(() {
      _loadScheduled = false;
      unawaited(_loadInitial());
    });
  }

  Future<void> _loadInitial() async {
    if (!ref.read(appSettingsProvider).momentsEnabled) {
      _retainedItems = const [];
      _retainedHasMore = true;
      _commit(const PagedMomentFeedState());
      return;
    }
    final blocking = _retainedItems.isEmpty;
    if (blocking) {
      _commit(state.copyWith(initialLoading: true, error: null));
    }
    _offset = 0;
    try {
      final service = ref.read(momentServiceProvider);
      final page = await service.loadFeedPage(limit: _pageSize, offset: 0);
      final unique = _uniqueById(page);
      _offset = page.length;
      _commit(
        PagedMomentFeedState(
          items: unique,
          hasMore: page.length == _pageSize,
        ),
      );
      _scheduleDeferredMaintenance(service);
    } catch (error) {
      _commit(
        PagedMomentFeedState(
          items: _retainedItems,
          hasMore: _retainedHasMore,
          initialLoading: false,
          error: error,
        ),
      );
    }
  }

  void _scheduleDeferredMaintenance(MomentService service) {
    if (_maintenanceScheduled) return;
    _maintenanceScheduled = true;
    unawaited((() async {
      try {
        final moved = await service.runDeferredFeedMaintenance();
        if (moved > 0) {
          ref.read(worldMomentRevisionProvider.notifier).state++;
        }
      } catch (_) {
        // Housekeeping must not block or break the feed.
      } finally {
        _maintenanceScheduled = false;
      }
    })());
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.initialLoading) return;
    _commit(state.copyWith(loadingMore: true));
    try {
      final page = await ref.read(momentServiceProvider).loadFeedPage(
            limit: _pageSize,
            offset: _offset,
          );
      _commit(
        PagedMomentFeedState(
          items: _uniqueById([...state.items, ...page]),
          hasMore: page.length == _pageSize,
        ),
      );
      _offset += page.length;
    } catch (error) {
      _commit(state.copyWith(error: error));
    } finally {
      _commit(state.copyWith(loadingMore: false));
    }
  }

  List<MomentFeedItem> _uniqueById(List<MomentFeedItem> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.post.id)) item,
    ];
  }
}

extension on PagedMomentFeedState {
  PagedMomentFeedState copyWith({
    List<MomentFeedItem>? items,
    bool? initialLoading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
  }) {
    return PagedMomentFeedState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

/// Character cards for authors on the current feed page — not the full library.
final momentFeedAuthorsProvider =
    FutureProvider.autoDispose<List<Character>>((ref) async {
  final items = ref.watch(
    pagedMomentFeedProvider.select((state) => state.items),
  );
  final ids = <String>{
    for (final item in items)
      if (item.post.origin == MomentPostOrigin.character) item.post.authorId,
  };
  if (ids.isEmpty) return const [];
  return ref.read(characterRepositoryProvider).getCharactersByIds(ids);
});
