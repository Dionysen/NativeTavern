import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/theme/system_font.dart';
import '../services/system_font_catalog.dart';

/// Font discovery, user imports, and [FontLoader] registration.
class FileSystemFontRepository {
  FileSystemFontRepository({
    SystemFontCatalog? catalog,
    Iterable<Directory>? directories,
    Future<Directory> Function()? importedFontsDirectory,
  })  : _catalog = catalog ?? SystemFontCatalog(),
        _directories = directories,
        _importedFontsDirectory =
            importedFontsDirectory ?? _defaultImportedFontsDirectory;

  final SystemFontCatalog _catalog;
  final Iterable<Directory>? _directories;
  final Future<Directory> Function() _importedFontsDirectory;
  final Map<String, String> _loadedFamilies = {};

  Future<List<SystemFont>> listFonts() async {
    final byPath = <String, SystemFont>{};
    final byFamily = <String, SystemFont>{};
    void add(SystemFont font) {
      if (font.family.isEmpty || font.path.isEmpty) {
        return;
      }
      final pathKey = font.path.toLowerCase();
      if (byPath.containsKey(pathKey)) {
        return;
      }
      final familyKey = font.family.toLowerCase();
      if (byFamily.containsKey(familyKey)) {
        return;
      }
      byPath[pathKey] = font;
      byFamily[familyKey] = font;
    }

    for (final font in await _listImportedFonts()) {
      add(font);
    }
    if (_supportsSystemFontDiscovery) {
      for (final font in await _catalog.listFonts()) {
        add(font);
      }
      for (final font in await _listDirectoryFonts()) {
        add(font);
      }
    }
    final fonts = byPath.values.toList()
      ..sort(
        (left, right) =>
            left.family.toLowerCase().compareTo(right.family.toLowerCase()),
      );
    return fonts;
  }

  Future<String?> loadFont(SystemFont font) async {
    final known = _loadedFamilies[font.path];
    if (known != null) {
      return known;
    }
    final file = File(font.path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final family = 'native-tavern-font-${font.path.hashCode}';
      final loader = FontLoader(family)
        ..addFont(file.readAsBytes().then(ByteData.sublistView));
      await loader.load();
      _loadedFamilies[font.path] = family;
      return family;
    } on Object {
      return null;
    }
  }

  Future<SystemFont?> importFont(String sourcePath) async {
    if (!_isFontFile(sourcePath)) {
      return null;
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      return null;
    }

    late final List<int> bytes;
    try {
      bytes = await source.readAsBytes();
    } on Object {
      return null;
    }
    if (bytes.isEmpty) {
      return null;
    }

    final dir = await _importedFontsDirectory();
    await dir.create(recursive: true);
    final digest = Object.hashAll(bytes);
    final originalName =
        p.basename(sourcePath).replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final dest = File(p.join(dir.path, '${digest}_$originalName'));
    if (!await dest.exists()) {
      await dest.writeAsBytes(bytes, flush: true);
    }

    return SystemFont(
      family: _displayName(sourcePath),
      path: dest.path,
      imported: true,
    );
  }

  Future<bool> deleteImportedFont(SystemFont font) async {
    if (!font.imported || font.path.isEmpty) {
      return false;
    }
    late final Directory root;
    try {
      root = await _importedFontsDirectory();
    } on Object {
      return false;
    }
    final rootPath = p.normalize(root.absolute.path);
    final fontPath = p.normalize(File(font.path).absolute.path);
    if (fontPath != rootPath && !p.isWithin(rootPath, fontPath)) {
      return false;
    }
    final file = File(fontPath);
    if (!await file.exists()) {
      _loadedFamilies.remove(font.path);
      _loadedFamilies.remove(fontPath);
      return true;
    }
    try {
      await file.delete();
      _loadedFamilies.remove(font.path);
      _loadedFamilies.remove(fontPath);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> fontFileMissing(String path) async {
    try {
      return !await File(path).exists();
    } on Object {
      return true;
    }
  }

  Future<List<SystemFont>> _listImportedFonts() async {
    final fonts = <SystemFont>[];
    try {
      final root = await _importedFontsDirectory();
      if (!await root.exists()) {
        return fonts;
      }
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! File || !_isFontFile(entity.path)) {
          continue;
        }
        fonts.add(
          SystemFont(
            family: _displayName(entity.path),
            path: entity.path,
            imported: true,
          ),
        );
      }
    } on Object {
      // Support directory may be unavailable in tests or restricted embeds.
    }
    return fonts;
  }

  Future<List<SystemFont>> _listDirectoryFonts() async {
    final fonts = <SystemFont>[];
    for (final root in _directories ?? _fontDirectories()) {
      if (!await root.exists()) {
        continue;
      }
      try {
        await for (final entity in root.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File || !_isFontFile(entity.path)) {
            continue;
          }
          fonts.add(
            SystemFont(family: _displayName(entity.path), path: entity.path),
          );
        }
      } on Object {
        // A directory may exist but be unreadable in a sandboxed build.
      }
    }
    return fonts;
  }

  Iterable<Directory> _fontDirectories() {
    final home = Platform.environment['HOME'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    return switch (Platform.operatingSystem) {
      'windows' => [
          Directory(r'C:\Windows\Fonts'),
          if (localAppData != null)
            Directory('$localAppData\\Microsoft\\Windows\\Fonts'),
        ],
      'macos' => [
          Directory('/System/Library/Fonts'),
          Directory('/Library/Fonts'),
          if (home != null) Directory('$home/Library/Fonts'),
        ],
      'linux' => [
          Directory('/usr/share/fonts'),
          Directory('/usr/local/share/fonts'),
          if (home != null) Directory('$home/.local/share/fonts'),
          if (home != null) Directory('$home/.fonts'),
        ],
      _ => const [],
    };
  }
}

bool get _supportsSystemFontDiscovery =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<Directory> _defaultImportedFontsDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'fonts'));
}

bool _isFontFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.ttf') ||
      lower.endsWith('.otf') ||
      lower.endsWith('.ttc') ||
      lower.endsWith('.otc');
}

String _displayName(String path) {
  var fileName = p.basename(path);
  fileName = fileName.replaceFirst(RegExp(r'^-?\d+_'), '');
  if (fileName.isEmpty) {
    fileName = p.basename(path);
  }
  return fileName.replaceFirst(
    RegExp(r'\.(ttf|otf|ttc|otc)$', caseSensitive: false),
    '',
  );
}
