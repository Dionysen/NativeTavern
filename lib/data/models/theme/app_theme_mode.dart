/// User preference for whether the shell follows light, dark, or the system.
enum AppThemeMode {
  system,
  light,
  dark;

  String get storageValue => name;

  static AppThemeMode fromStorage(String? value) => switch (value) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };
}
