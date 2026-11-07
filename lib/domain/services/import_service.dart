import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/character_card_codec.dart';
import 'package:native_tavern/data/models/live2d.dart';
import 'package:native_tavern/core/utils/path_utils.dart';
import 'package:native_tavern/core/utils/png_text_chunks.dart';
import 'package:path/path.dart' as p;

/// Service for importing and exporting character cards
class ImportService {
  final String _dataPath;

  ImportService(this._dataPath);

  String get dataPath => _dataPath;

  /// Import character from PNG file (extracts embedded JSON from tEXt chunk)
  Future<Character> importFromPng(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return importFromPngBytes(bytes);
  }

  /// Import character from PNG bytes (extracts embedded JSON from tEXt chunk)
  Future<Character> importFromPngBytes(Uint8List bytes) async {
    // Extract character data from PNG tEXt chunk
    final payload = extractPngTextChunk(bytes, 'ccv3') ??
        extractPngTextChunk(bytes, 'chara');
    if (payload == null) {
      throw Exception('No character data found in PNG');
    }

    final data = _decodeCharacterPayload(payload);

    // Parse character from JSON
    final character = _parseCharacterJson(data);

    // Save the avatar
    final avatarPath = await _saveAvatar(character.id, bytes);

    return character.copyWith(
      assets: CharacterAssets(avatarPath: avatarPath),
    );
  }

  /// Import character from CharX archive
  Future<Character> importFromCharX(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Extract archive
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find card.json
    ArchiveFile? cardFile;
    ArchiveFile? avatarFile;

    for (final file in archive) {
      if (file.name == 'card.json') {
        cardFile = file;
      } else if (file.name.endsWith('.png') || file.name.endsWith('.jpg')) {
        avatarFile = file;
      }
    }

    if (cardFile == null) {
      throw Exception('No card.json found in CharX archive');
    }

    // Parse JSON
    final json = utf8.decode(cardFile.content as List<int>);
    final data = jsonDecode(json) as Map<String, dynamic>;

    // Parse character
    final character = _parseCharacterJson(data);

    // Save avatar if found
    String? avatarPath;
    if (avatarFile != null) {
      avatarPath = await _saveAvatar(
          character.id, Uint8List.fromList(avatarFile.content as List<int>));
    }

    return character.copyWith(
      assets:
          avatarPath != null ? CharacterAssets(avatarPath: avatarPath) : null,
    );
  }

  /// Import character from JSON string
  Future<Character> importFromJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return _parseCharacterJson(data);
  }

  /// Creates a playable character bound to an already-imported Live2D model.
  Future<Character> createCharacterFromLive2D({
    required Live2DModelDefinition definition,
    required Live2DConfig config,
    List<int>? avatarBytes,
  }) async {
    final now = DateTime.now();
    final id = _generateId();
    String? avatarPath;
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      avatarPath = await _saveAvatar(id, Uint8List.fromList(avatarBytes));
    }
    return Character(
      id: id,
      name: definition.displayName,
      assets: CharacterAssets(
        avatarPath: avatarPath,
        live2d: config.copyWith(enabled: true),
      ),
      createdAt: now,
      modifiedAt: now,
    );
  }

  /// Export character to PNG with embedded data (`ccv3` + `chara`).
  Future<Uint8List> exportToPng(
      Character character, Uint8List? avatarData) async {
    var imageBytes = avatarData ?? await _loadAvatarBytes(character);
    imageBytes ??= _createPlaceholderPng();

    // Drop prior card payloads so re-export does not stack duplicate chunks.
    imageBytes = stripPngTextChunks(imageBytes, const {'chara', 'ccv3'});

    final encoded =
        base64Encode(utf8.encode(CharacterCardCodec.toV3JsonString(character)));
    // Write both keywords for ST V3 + broad community compatibility.
    var out = embedPngTextChunk(imageBytes, 'ccv3', encoded);
    out = embedPngTextChunk(out, 'chara', encoded);
    return out;
  }

  /// Export character to CharX archive
  Future<Uint8List> exportToCharX(
      Character character, Uint8List? avatarData) async {
    final encoder = ZipEncoder();
    final archive = Archive();

    final jsonBytes =
        utf8.encode(CharacterCardCodec.toV3JsonString(character));
    archive.addFile(ArchiveFile('card.json', jsonBytes.length, jsonBytes));

    final bytes = avatarData ?? await _loadAvatarBytes(character);
    if (bytes != null) {
      archive.addFile(ArchiveFile('avatar.png', bytes.length, bytes));
    }

    return Uint8List.fromList(encoder.encode(archive)!);
  }

  /// Export character to JSON
  String exportToJson(Character character) {
    return CharacterCardCodec.toV3JsonString(character);
  }

  // Private methods

  Character _parseCharacterJson(Map<String, dynamic> json) {
    return CharacterCardCodec.parse(json, generateId: _generateId);
  }

  Future<Uint8List?> _loadAvatarBytes(Character character) async {
    final relative = character.assets?.avatarPath;
    if (relative == null || relative.isEmpty) return null;
    try {
      final absolute = await PathUtils.toAbsolutePath(relative);
      final file = File(absolute);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {
      // Fall through to missing avatar.
    }
    return null;
  }

  Map<String, dynamic> _decodeCharacterPayload(String payload) {
    final trimmed = payload.trim();
    final candidates = <String>[trimmed];
    final dataPrefix = trimmed.indexOf('base64,');
    if (dataPrefix >= 0) {
      candidates.add(trimmed.substring(dataPrefix + 'base64,'.length));
    }

    for (final candidate in candidates.reversed) {
      try {
        final decoded = utf8.decode(base64Decode(base64.normalize(candidate)));
        final json = jsonDecode(decoded);
        if (json is Map<String, dynamic>) return json;
      } catch (_) {
        // Try the next representation.
      }
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {
      // Report a stable import error below.
    }
    throw const FormatException('Character card metadata is not valid JSON');
  }

  Future<String> _saveAvatar(String characterId, Uint8List imageData) async {
    final avatarDir = Directory(p.join(_dataPath, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    final avatarPath = p.join(avatarDir.path, '$characterId.png');
    await File(avatarPath).writeAsBytes(imageData);

    // Return relative path for storage (mobile-compatible)
    return await PathUtils.toRelativePath(avatarPath);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  }

  /// Create a simple placeholder PNG
  Uint8List _createPlaceholderPng() {
    // A minimal 1x1 transparent PNG
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
      0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, // width = 1
      0x00, 0x00, 0x00, 0x01, // height = 1
      0x08, 0x06, 0x00, 0x00, 0x00, // 8-bit RGBA
      0x1F, 0x15, 0xC4, 0x89, // CRC
      0x00, 0x00, 0x00, 0x0A, // IDAT chunk length
      0x49, 0x44, 0x41, 0x54, // IDAT
      0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
      0x0D, 0x0A, 0x2D, 0xB4, // CRC
      0x00, 0x00, 0x00, 0x00, // IEND chunk length
      0x49, 0x45, 0x4E, 0x44, // IEND
      0xAE, 0x42, 0x60, 0x82, // CRC
    ]);
  }
}
