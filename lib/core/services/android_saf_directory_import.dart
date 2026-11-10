import 'package:flutter/services.dart';

/// Android scoped-storage helper for character-library folder import.
///
/// [file_picker]'s [getDirectoryPath] uses SAF then tries to resolve a real
/// filesystem path. That commonly fails (`unknown_path`) and is swallowed as
/// `null`, which looks like "tap does nothing". This channel copies the chosen
/// tree into app cache and returns a path dart:io can read.
class AndroidSafDirectoryImport {
  AndroidSafDirectoryImport._();

  static const MethodChannel _channel = MethodChannel('com.nativetavern/saf');

  static const defaultExtensions = <String>['.png', '.json', '.charx'];

  /// Opens the system folder picker, copies matching files into cache, and
  /// returns that cache directory path. Returns `null` if the user cancels.
  static Future<String?> pickAndCopyImportTree({
    List<String> extensions = defaultExtensions,
  }) {
    return _channel.invokeMethod<String>(
      'pickAndCopyImportTree',
      <String, Object?>{'extensions': extensions},
    );
  }
}
