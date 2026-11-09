import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/image_generation_service.dart';

void main() {
  group('ImageGenSettings effectiveEndpoint', () {
    test('adds /v1 to an OpenAI-compatible root URL', () {
      const settings = ImageGenSettings(
        provider: ImageGenProvider.openai,
        apiEndpoints: {
          'openai': '  https://oneapi.example.com/  ',
        },
      );

      expect(settings.effectiveEndpoint, 'https://oneapi.example.com/v1');
    });

    test('preserves an existing /v1 base path', () {
      const settings = ImageGenSettings(
        provider: ImageGenProvider.openai,
        apiEndpoints: {
          'openai': 'https://oneapi.example.com/v1/',
        },
      );

      expect(settings.effectiveEndpoint, 'https://oneapi.example.com/v1');
    });

    test('preserves a custom API base path', () {
      const settings = ImageGenSettings(
        provider: ImageGenProvider.openaiChat,
        apiEndpoints: {
          'openai_chat': 'https://proxy.example.com/api/v1/',
        },
      );

      expect(settings.effectiveEndpoint, 'https://proxy.example.com/api/v1');
    });

    test('accepts a full image generations endpoint', () {
      const settings = ImageGenSettings(
        provider: ImageGenProvider.openai,
        apiEndpoints: {
          'openai': 'https://oneapi.example.com/v1/images/generations',
        },
      );

      expect(settings.effectiveEndpoint, 'https://oneapi.example.com/v1');
    });

    test('accepts a full chat completions endpoint', () {
      const settings = ImageGenSettings(
        provider: ImageGenProvider.openaiChat,
        apiEndpoints: {
          'openai_chat': 'https://proxy.example.com/v1/chat/completions/',
        },
      );

      expect(settings.effectiveEndpoint, 'https://proxy.example.com/v1');
    });

    test('only removes trailing slashes for other providers', () {
      const settings = ImageGenSettings(
        provider: ImageGenProvider.automatic1111,
        apiEndpoints: {
          'automatic1111': 'http://localhost:7860/',
        },
      );

      expect(settings.effectiveEndpoint, 'http://localhost:7860');
    });
  });

  group('ComfyUiWorkflow', () {
    test('maps app sampler ids to ComfyUI names', () {
      expect(ComfyUiWorkflow.samplerName('euler_a'), 'euler_ancestral');
      expect(ComfyUiWorkflow.samplerName('dpmpp_2m'), 'dpmpp_2m');
      expect(ComfyUiWorkflow.samplerName('k_euler_ancestral'), 'euler_ancestral');
    });

    test('falls back unknown schedulers to normal', () {
      expect(ComfyUiWorkflow.schedulerName('karras'), 'karras');
      expect(ComfyUiWorkflow.schedulerName('weird'), 'normal');
    });

    test('adds v-prediction nodes for NoobAI V-pred checkpoints', () {
      final workflow = ComfyUiWorkflow.buildTxt2Img(
        ckptName: 'NoobAI-XL-Vpred-v1.0.safetensors',
        prompt: '1girl',
        negativePrompt: 'lowres',
        width: 768,
        height: 768,
        steps: 16,
        cfg: 4.5,
        seed: 1,
        samplerName: 'euler',
        scheduler: 'normal',
      );

      expect(workflow['2']?['class_type'], 'ModelSamplingDiscrete');
      expect(workflow['3']?['class_type'], 'RescaleCFG');
      expect(workflow['7']?['inputs']?['model'], ['3', 0]);
      expect(workflow['1']?['inputs']?['ckpt_name'],
          'NoobAI-XL-Vpred-v1.0.safetensors');
    });

    test('keeps a plain graph for non v-pred checkpoints', () {
      final workflow = ComfyUiWorkflow.buildTxt2Img(
        ckptName: 'v1-5-pruned-emaonly.safetensors',
        prompt: 'cat',
        negativePrompt: '',
        width: 512,
        height: 512,
        steps: 20,
        cfg: 7,
        seed: 2,
        samplerName: 'euler',
        scheduler: 'normal',
      );

      expect(workflow.containsKey('2'), isFalse);
      expect(workflow.containsKey('3'), isFalse);
      expect(workflow['7']?['inputs']?['model'], ['1', 0]);
    });
  });
}
