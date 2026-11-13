import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/core/app_scope.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/domain/services/live2d_import_service.dart';
import 'package:native_tavern/domain/services/live2d_model_lifecycle_service.dart';
import 'package:native_tavern/domain/services/live2d_service.dart';

final live2DServiceProvider = Provider<Live2DService>((ref) {
  return Live2DService(dataPath: ref.watch(dataPathProvider));
});

final live2DImportServiceProvider = Provider<Live2DImportService>((ref) {
  return Live2DImportService(
    dataPath: ref.watch(dataPathProvider),
    modelService: ref.watch(live2DServiceProvider),
  );
});

final live2DModelLifecycleServiceProvider =
    Provider<Live2DModelLifecycleService>((ref) {
  return Live2DModelLifecycleService(
    characterRepository: ref.watch(characterRepositoryProvider),
    importService: ref.watch(live2DImportServiceProvider),
  );
});
