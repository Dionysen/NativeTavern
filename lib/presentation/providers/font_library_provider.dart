import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/theme/system_font.dart';
import '../../data/repositories/file_system_font_repository.dart';

class FontLibraryState {
  const FontLibraryState({
    this.fonts = const [],
    this.isLoading = false,
    this.hasLoaded = false,
  });

  final List<SystemFont> fonts;
  final bool isLoading;
  final bool hasLoaded;

  FontLibraryState copyWith({
    List<SystemFont>? fonts,
    bool? isLoading,
    bool? hasLoaded,
  }) =>
      FontLibraryState(
        fonts: fonts ?? this.fonts,
        isLoading: isLoading ?? this.isLoading,
        hasLoaded: hasLoaded ?? this.hasLoaded,
      );
}

final fontRepositoryProvider = Provider<FileSystemFontRepository>((ref) {
  return FileSystemFontRepository();
});

final fontLibraryProvider =
    NotifierProvider<FontLibraryNotifier, FontLibraryState>(
  FontLibraryNotifier.new,
);

class FontLibraryNotifier extends Notifier<FontLibraryState> {
  late final FileSystemFontRepository _repository;

  @override
  FontLibraryState build() {
    _repository = ref.watch(fontRepositoryProvider);
    return const FontLibraryState();
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (state.isLoading) {
      return;
    }
    if (state.hasLoaded && !force) {
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final fonts = await _repository.listFonts();
      state = state.copyWith(fonts: fonts, hasLoaded: true, isLoading: false);
    } on Object {
      state = state.copyWith(isLoading: false, hasLoaded: true);
    }
  }

  Future<String?> loadFont(SystemFont font) => _repository.loadFont(font);

  Future<SystemFont?> importFont(String sourcePath) async {
    final imported = await _repository.importFont(sourcePath);
    if (imported == null) {
      return null;
    }
    try {
      final fonts = await _repository.listFonts();
      state = state.copyWith(fonts: fonts, hasLoaded: true);
    } on Object {
      if (!state.fonts.any((font) => font.path == imported.path)) {
        state = state.copyWith(fonts: [...state.fonts, imported], hasLoaded: true);
      }
    }
    return imported;
  }

  Future<bool> deleteImportedFont(SystemFont font) async {
    final ok = await _repository.deleteImportedFont(font);
    if (!ok) {
      return false;
    }
    try {
      final fonts = await _repository.listFonts();
      state = state.copyWith(fonts: fonts, hasLoaded: true);
    } on Object {
      state = state.copyWith(
        fonts: state.fonts.where((item) => item.path != font.path).toList(),
      );
    }
    return true;
  }

  Future<bool> fontFileMissing(String path) =>
      _repository.fontFileMissing(path);
}
