import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';
import 'package:native_tavern_qnn_upscale/native_tavern_qnn_upscale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NativeTavernQnnUpscale.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('localQnn provider metadata', () {
    expect(ImageGenProvider.localQnn.isOnDeviceQnn, isTrue);
    expect(ImageGenProvider.localQnn.isLocalProvider, isTrue);
    expect(ImageGenProvider.localQnn.requiresApiKey, isFalse);
    expect(ImageGenProvider.localQnn.defaultModels, contains('anythingv5'));
    expect(
      ImageGenSampler.forProvider(ImageGenProvider.localQnn).map((s) => s.id),
      containsAll(['dpm', 'euler_a']),
    );
  });

  test('generate fails clearly when backend is not ready', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getBackendStatus':
          return <String, Object?>{
            'state': 'idle',
            'modelId': null,
            'modelName': null,
            'progress': null,
            'message': null,
          };
        default:
          fail('Unexpected method ${call.method}');
      }
    });

    final service = ImageGenerationService(
      localQnn: const NativeTavernQnnUpscale(),
    )..updateSettings(
        const ImageGenSettings(
          enabled: true,
          provider: ImageGenProvider.localQnn,
          models: {'local_qnn': 'anythingv5'},
          defaultWidth: 512,
          defaultHeight: 512,
        ),
      );

    final result = await service.generate(
      const ImageGenRequest(prompt: 'a cat', width: 512, height: 512),
    );
    // generate() catches errors and returns null rather than throwing.
    expect(result, isNull);
  });

  test('startModel and stopModel round-trip through channel', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'startModel') {
        expect(call.arguments['modelId'], 'anythingv5');
        return <String, Object?>{
          'state': 'ready',
          'modelId': 'anythingv5',
          'modelName': 'Anything V5.0',
          'progress': 1.0,
          'message': 'Ready',
        };
      }
      if (call.method == 'stopModel') {
        return <String, Object?>{
          'state': 'idle',
          'modelId': null,
          'modelName': null,
          'progress': null,
          'message': null,
        };
      }
      fail('Unexpected ${call.method}');
    });

    const plugin = NativeTavernQnnUpscale();
    final started = await plugin.startModel('anythingv5');
    expect(started.isReady, isTrue);
    expect(started.modelId, 'anythingv5');

    final stopped = await plugin.stopModel();
    expect(stopped.state, 'idle');
    expect(calls, ['startModel', 'stopModel']);
  });
}
