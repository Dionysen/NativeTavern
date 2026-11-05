/// Persisted UI font family choices (generic families, cross-platform).
abstract final class AppFontFamily {
  static const system = 'system';
  static const serif = 'serif';
  static const monospace = 'monospace';

  static const ids = [system, serif, monospace];

  /// [ThemeData.fontFamily] value, or null for the platform default.
  static String? resolve(String id) => switch (id) {
        serif => 'serif',
        monospace => 'monospace',
        _ => null,
      };
}
