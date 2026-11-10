import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/image_gen_history_service.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late ImageGenHistoryService history;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nt_img_hist_');
    history = ImageGenHistoryService(rootOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('record then list and delete', () async {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final created = await history.record(
      request: const ImageGenRequest(
        prompt: 'a cat',
        negativePrompt: 'blurry',
        width: 512,
        height: 768,
        steps: 20,
        cfgScale: 7,
        sampler: 'euler_a',
        model: 'test-model',
        seed: 42,
      ),
      result: ImageGenResult(
        images: [bytes],
        prompt: 'a cat',
        seed: 42,
        format: 'png',
      ),
      settings: const ImageGenSettings(
        provider: ImageGenProvider.pollinations,
      ),
    );

    expect(created, hasLength(1));
    expect(File(created.first.imagePath).existsSync(), isTrue);

    final listed = await history.listEntries();
    expect(listed, hasLength(1));
    expect(listed.first.prompt, 'a cat');
    expect(listed.first.negativePrompt, 'blurry');
    expect(listed.first.width, 512);
    expect(listed.first.height, 768);
    expect(listed.first.seed, 42);
    expect(listed.first.provider, 'pollinations');

    await history.delete(listed.first.id);
    expect(await history.listEntries(), isEmpty);
    expect(
      Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(listed.first.id))
          .toList(),
      isEmpty,
    );
  });
}
