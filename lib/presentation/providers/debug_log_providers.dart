import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/debug_log_service.dart';

final debugLogServiceProvider = Provider<DebugLogService>((ref) {
  return DebugLogService();
});

final logEntriesStreamProvider = StreamProvider<LogEntry>((ref) {
  final service = ref.watch(debugLogServiceProvider);
  return service.logStream;
});

final currentLogsProvider = Provider<List<LogEntry>>((ref) {
  ref.watch(logEntriesStreamProvider);
  final service = ref.watch(debugLogServiceProvider);
  return service.logs;
});
