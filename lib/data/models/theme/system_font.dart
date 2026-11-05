/// A discoverable or imported font file the app can register with [FontLoader].
class SystemFont {
  const SystemFont({
    required this.family,
    required this.path,
    this.imported = false,
  });

  final String family;
  final String path;

  /// True when the file lives in the app-owned fonts directory.
  final bool imported;

  @override
  bool operator ==(Object other) => other is SystemFont && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
