import 'dart:io';

import 'package:flutter/services.dart';

import '../models/theme/system_font.dart';

/// Platform font registry with human-readable family names.
///
/// macOS uses Core Text via a method channel. Windows reads the font registry
/// so entries like `msyh.ttc` appear as localized names instead of file stems.
class SystemFontCatalog {
  SystemFontCatalog({
    MethodChannel? channel,
    Future<String> Function(List<String> arguments)? runReg,
  })  : _channel = channel ?? const MethodChannel('native_tavern/system_fonts'),
        _runReg = runReg ?? _defaultRunReg;

  final MethodChannel _channel;
  final Future<String> Function(List<String> arguments) _runReg;

  Future<List<SystemFont>> listFonts() async {
    if (Platform.isMacOS) {
      return _listMacOSFonts();
    }
    if (Platform.isWindows) {
      return _listWindowsFonts();
    }
    return const [];
  }

  Future<List<SystemFont>> _listMacOSFonts() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listFonts');
      if (raw == null) {
        return const [];
      }
      return [
        for (final item in raw)
          if (item is Map)
            SystemFont(
              family: item['family'] as String? ?? '',
              path: item['path'] as String? ?? '',
            ),
      ].where((font) => font.family.isNotEmpty && font.path.isNotEmpty).toList();
    } on Object {
      return const [];
    }
  }

  Future<List<SystemFont>> _listWindowsFonts() async {
    final fonts = <SystemFont>[];
    final seenPaths = <String>{};
    for (final key in const [
      r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      r'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
    ]) {
      try {
        final output = await _runReg(['query', key]);
        for (final entry in _parseRegFonts(output)) {
          final path = _resolveWindowsFontPath(entry.fileName);
          if (path == null || !seenPaths.add(path.toLowerCase())) {
            continue;
          }
          fonts.add(
            SystemFont(
              family: _windowsDisplayName(entry.registryName, entry.fileName),
              path: path,
            ),
          );
        }
      } on Object {
        // Registry access can fail in restricted environments.
      }
    }
    return fonts;
  }
}

Future<String> _defaultRunReg(List<String> arguments) async {
  final result = await Process.run('reg', arguments, runInShell: false);
  if (result.exitCode != 0) {
    throw ProcessException(
      'reg',
      arguments,
      '${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout as String;
}

class _RegFont {
  const _RegFont({required this.registryName, required this.fileName});
  final String registryName;
  final String fileName;
}

Iterable<_RegFont> _parseRegFonts(String output) sync* {
  final pattern = RegExp(
    r'^\s*(.+?)\s+REG_SZ\s+(.+?)\s*$',
    multiLine: true,
  );
  for (final match in pattern.allMatches(output)) {
    final name = match.group(1)?.trim() ?? '';
    final fileName = match.group(2)?.trim() ?? '';
    if (name.isEmpty ||
        fileName.isEmpty ||
        name == '(Default)' ||
        name == '默认') {
      continue;
    }
    yield _RegFont(registryName: name, fileName: fileName);
  }
}

String? _resolveWindowsFontPath(String fileName) {
  final normalized = fileName.trim().replaceAll('/', '\\');
  if (normalized.contains('\\') || normalized.contains(':')) {
    return normalized;
  }
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  return '$windir\\Fonts\\$normalized';
}

String _windowsDisplayName(String registryName, String fileName) {
  final baseName = Uri.file(
    fileName.replaceAll('/', '\\'),
  ).pathSegments.last.toLowerCase();
  final known = _windowsKnownFamilies[baseName];
  if (known != null) {
    return known;
  }
  var name = registryName
      .replaceFirst(RegExp(r'\s*\((TrueType|OpenType)\)\s*$'), '')
      .trim();
  final amp = name.indexOf(' & ');
  if (amp > 0) {
    name = name.substring(0, amp).trim();
  }
  return name.isEmpty ? baseName : name;
}

const _windowsKnownFamilies = <String, String>{
  'msyh.ttc': '微软雅黑',
  'msyhbd.ttc': '微软雅黑 Bold',
  'msyhl.ttc': '微软雅黑 Light',
  'msjh.ttc': '微软正黑体',
  'msjhbd.ttc': '微软正黑体 Bold',
  'msjhl.ttc': '微软正黑体 Light',
  'simsun.ttc': '宋体',
  'simsunb.ttf': '宋体-ExtB',
  'simhei.ttf': '黑体',
  'simkai.ttf': '楷体',
  'simfang.ttf': '仿宋',
  'simli.ttf': '隶书',
  'simyou.ttf': '幼圆',
  'deng.ttf': '等线',
  'dengb.ttf': '等线 Bold',
  'dengl.ttf': '等线 Light',
  'nsimsun.ttc': '新宋体',
};
