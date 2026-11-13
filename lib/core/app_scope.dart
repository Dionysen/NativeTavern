import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/database/database.dart';

/// Overridden in [ProviderScope] after startup. Declared here so data
/// repositories can watch it without depending on the presentation layer.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Root directory for user-managed NativeTavern data.
final dataPathProvider = Provider<String>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
