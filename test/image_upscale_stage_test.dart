import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:native_tavern/domain/services/image_upscale/image_upscale_backend.dart';
import 'package:native_tavern/domain/services/image_upscale/image_upscale_stage.dart';
import 'package:native_tavern/domain/services/image_upscale/noop_image_upscale_backend.dart';

class _FakeUpscaleBackend implements ImageUpscaleBackend {
  _FakeUpscaleBackend({
    this.available = true,
    this.throwOnUpscale = false,
  });

  final bool available;
  final bool throwOnUpscale;
  var ensureReadyCalls = 0;
  var upscaleCalls = 0;

  @override
  Future<ImageUpscaleCapability> getCapability() async {
    return available
        ? const ImageUpscaleCapability(
            available: true,
            hasNativeRuntime: true,
            modelReady: true,
          )
        : const ImageUpscaleCapability.unavailable('fake unavailable');
  }

  @override
  Future<void> ensureReady() async {
    ensureReadyCalls++;
  }

  @override
  Future<Uint8List> upscale(ImageUpscaleRequest request) async {
    upscaleCalls++;
    if (throwOnUpscale) {
      throw StateError('boom');
    }
    final out = img.Image(
      width: request.width * 4,
      height: request.height * 4,
    );
    img.fill(out, color: img.ColorRgb8(10, 20, 30));
    return Uint8List.fromList(img.encodeJpg(out));
  }

  @override
  Future<void> dispose() async {}
}

Uint8List _tinyPng({int width = 32, int height = 32}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('disabled stage returns original bytes', () async {
    final original = [_tinyPng()];
    final backend = _FakeUpscaleBackend();
    final result = await ImageUpscaleStage(backend: backend).apply(
      images: original,
      enabled: false,
      targetScale: 4,
    );
    expect(result.didUpscale, isFalse);
    expect(result.images, same(original));
    expect(backend.upscaleCalls, 0);
  });

  test('unavailable backend passes through', () async {
    final original = [_tinyPng()];
    final backend = _FakeUpscaleBackend(available: false);
    final result = await ImageUpscaleStage(backend: backend).apply(
      images: original,
      enabled: true,
      targetScale: 4,
    );
    expect(result.didUpscale, isFalse);
    expect(identical(result.images, original), isTrue);
    expect(backend.ensureReadyCalls, 0);
  });

  test('noop backend skips without throwing', () async {
    final original = [_tinyPng()];
    final result = await const ImageUpscaleStage().apply(
      images: original,
      enabled: true,
      targetScale: 4,
    );
    expect(result.didUpscale, isFalse);
    expect(result.images, same(original));
  });

  test('available backend replaces images', () async {
    final original = [_tinyPng()];
    final backend = _FakeUpscaleBackend();
    final result = await ImageUpscaleStage(backend: backend).apply(
      images: original,
      enabled: true,
      targetScale: 4,
    );
    expect(result.didUpscale, isTrue);
    expect(backend.upscaleCalls, 1);
    expect(result.images.first, isNot(equals(original.first)));
    final decoded = img.decodeImage(result.images.first)!;
    expect(decoded.width, 128);
    expect(decoded.height, 128);
  });

  test('upscale failure keeps original image', () async {
    final original = [_tinyPng()];
    final backend = _FakeUpscaleBackend(throwOnUpscale: true);
    final result = await ImageUpscaleStage(backend: backend).apply(
      images: original,
      enabled: true,
      targetScale: 4,
    );
    expect(result.didUpscale, isFalse);
    expect(result.images.single, same(original.single));
  });

  test('oversized image is skipped', () async {
    final original = [_tinyPng(width: 1200, height: 800)];
    final backend = _FakeUpscaleBackend();
    final result = await ImageUpscaleStage(backend: backend).apply(
      images: original,
      enabled: true,
      targetScale: 4,
    );
    expect(result.didUpscale, isFalse);
    expect(backend.upscaleCalls, 0);
  });

  test('noop capability stays unavailable', () async {
    final capability = await const NoopImageUpscaleBackend().getCapability();
    expect(capability.available, isFalse);
  });
}
