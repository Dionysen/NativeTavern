import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/screens/character/character_view_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Note: characterRepositoryProvider is defined in character_repository.dart

/// Selected character state
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);

const _characterViewModeKey = 'character_browse_view_mode';
const _characterAvatarShapeKey = 'character_browse_avatar_shape';

class CharacterBrowseDisplayPrefs {
  const CharacterBrowseDisplayPrefs({
    required this.viewMode,
    required this.avatarShape,
  });

  final CharacterViewMode viewMode;
  final CharacterAvatarShape avatarShape;

  CharacterBrowseDisplayPrefs copyWith({
    CharacterViewMode? viewMode,
    CharacterAvatarShape? avatarShape,
  }) {
    return CharacterBrowseDisplayPrefs(
      viewMode: viewMode ?? this.viewMode,
      avatarShape: avatarShape ?? this.avatarShape,
    );
  }
}

final characterBrowseDisplayPrefsProvider = StateNotifierProvider<
    CharacterBrowseDisplayPrefsNotifier, CharacterBrowseDisplayPrefs>((ref) {
  return CharacterBrowseDisplayPrefsNotifier(
    ref.watch(sharedPreferencesProvider),
  );
});

class CharacterBrowseDisplayPrefsNotifier
    extends StateNotifier<CharacterBrowseDisplayPrefs> {
  CharacterBrowseDisplayPrefsNotifier(this._prefs)
      : super(
          CharacterBrowseDisplayPrefs(
            viewMode: _readViewMode(_prefs),
            avatarShape: _readAvatarShape(_prefs),
          ),
        );

  final SharedPreferences _prefs;

  static CharacterViewMode _readViewMode(SharedPreferences prefs) {
    final raw = prefs.getString(_characterViewModeKey);
    return CharacterViewMode.values.asNameMap()[raw] ??
        CharacterViewMode.compactGrid;
  }

  static CharacterAvatarShape _readAvatarShape(SharedPreferences prefs) {
    final raw = prefs.getString(_characterAvatarShapeKey);
    return CharacterAvatarShape.values.asNameMap()[raw] ??
        CharacterAvatarShape.circle;
  }

  Future<void> setViewMode(CharacterViewMode viewMode) async {
    state = state.copyWith(viewMode: viewMode);
    await _prefs.setString(_characterViewModeKey, viewMode.name);
  }

  Future<void> setAvatarShape(CharacterAvatarShape avatarShape) async {
    state = state.copyWith(avatarShape: avatarShape);
    await _prefs.setString(_characterAvatarShapeKey, avatarShape.name);
  }

  Future<void> cycleViewMode() => setViewMode(state.viewMode.next);

  Future<void> cycleAvatarShape() => setAvatarShape(state.avatarShape.next);
}

/// Character details, invalidated after editor writes so open screens refresh.
final characterDetailProvider =
    FutureProvider.family<Character?, String>((ref, id) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(id);
});

/// Selected tag labels for filtering the character browser (match all).
final characterBrowseTagFilterProvider = StateProvider<Set<String>>((ref) => {});

final characterLibraryTagLabelsProvider =
    FutureProvider<List<String>>((ref) async {
  return ref.read(characterRepositoryProvider).listDistinctCharacterTagLabels();
});

/// Character list provider
final characterListProvider =
    AsyncNotifierProvider<CharacterListNotifier, List<Character>>(() {
  return CharacterListNotifier();
});

/// Character list notifier
class CharacterListNotifier extends AsyncNotifier<List<Character>> {
  static const _pageSize = 40;
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  String _query = '';

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;

  bool _searchGlobally() {
    final folderId = ref.read(characterBrowseFolderIdProvider);
    if (folderId == null) return true;
    return ref.read(characterSearchGlobalProvider);
  }

  List<String> _requiredTags() {
    final tags = ref.read(characterBrowseTagFilterProvider).toList()
      ..sort();
    return tags;
  }

  Future<List<Character>> _fetchPage({required int offset}) {
    return ref.read(characterRepositoryProvider).getCharactersPage(
          limit: _pageSize,
          offset: offset,
          query: _query,
          browseFolderId: ref.read(characterBrowseFolderIdProvider),
          searchGlobally: _searchGlobally(),
          requiredTags: _requiredTags(),
        );
  }

  @override
  Future<List<Character>> build() async {
    ref.watch(characterBrowseFolderIdProvider);
    ref.watch(characterSearchGlobalProvider);
    ref.watch(characterBrowseTagFilterProvider);
    ref.watch(characterRepositoryProvider);
    _offset = 0;
    _hasMore = true;
    final page = await _fetchPage(offset: 0);
    _offset = page.length;
    _hasMore = page.length == _pageSize;
    return page;
  }

  Future<void> refresh() async {
    _offset = 0;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await _fetchPage(offset: 0);
      _offset = page.length;
      _hasMore = page.length == _pageSize;
      return page;
    });
  }

  Future<void> setQuery(String query) async {
    _query = query.trim();
    await refresh();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || !state.hasValue) return;
    _loadingMore = true;
    try {
      final page = await _fetchPage(offset: _offset);
      final current = state.valueOrNull ?? const <Character>[];
      state = AsyncData([...current, ...page]);
      _offset += page.length;
      _hasMore = page.length == _pageSize;
    } catch (error, stack) {
      state = AsyncError(error, stack);
    } finally {
      _loadingMore = false;
    }
  }

  Future<Character> addCharacter(Character character) async {
    final repo = ref.read(characterRepositoryProvider);
    final createdCharacter = await repo.createCharacter(character);
    ref.invalidate(characterLibraryTagLabelsProvider);
    await refresh();
    return createdCharacter;
  }

  Future<void> updateCharacter(Character character) async {
    final repo = ref.read(characterRepositoryProvider);
    await repo.updateCharacter(character);
    await _refreshFolderChrome();
    ref.invalidate(characterLibraryTagLabelsProvider);
    await refresh();
  }

  Future<void> deleteCharacter(String id) async {
    final repo = ref.read(characterRepositoryProvider);
    await repo.deleteCharacter(id);
    await _refreshFolderChrome();
    ref.invalidate(characterLibraryTagLabelsProvider);
    await refresh();
  }

  Future<void> deleteCharacters(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return;
    final repo = ref.read(characterRepositoryProvider);
    for (final id in uniqueIds) {
      await repo.deleteCharacter(id);
    }
    await _refreshFolderChrome();
    ref.invalidate(characterLibraryTagLabelsProvider);
    await refresh();
  }

  Future<void> _refreshFolderChrome() async {
    await ref.read(characterFoldersProvider.notifier).refresh();
  }
}

/// Selected character provider
final selectedCharacterProvider = FutureProvider<Character?>((ref) async {
  final id = ref.watch(selectedCharacterIdProvider);
  if (id == null) return null;

  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(id);
});

/// Character search provider
final characterSearchProvider =
    FutureProvider.family<List<Character>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final repo = ref.watch(characterRepositoryProvider);
  return repo.searchCharacters(query);
});
