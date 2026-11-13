import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/translation_service.dart';

void main() {
  group('TranslationSettings', () {
    test('round-trips and falls back when the provider id is unknown', () {
      const settings = TranslationSettings(
        enabled: true,
        provider: TranslationProvider.deepl,
        sourceLanguage: 'zh',
        targetLanguage: 'en',
        autoTranslateIncoming: true,
        apiKey: 'secret',
        apiEndpoint: 'https://example.test',
      );

      final restored = TranslationSettings.fromJson(settings.toJson());
      expect(restored.provider, TranslationProvider.deepl);
      expect(restored.sourceLanguage, 'zh');
      expect(restored.autoTranslateIncoming, isTrue);
      expect(restored.apiKey, 'secret');

      final unknown = TranslationSettings.fromJson({'provider': 'missing'});
      expect(unknown.provider, TranslationProvider.google);
      expect(unknown.enabled, isFalse);
    });

    test('target languages exclude auto-detect', () {
      expect(
        TranslationLanguage.targetLanguages.map((language) => language.code),
        isNot(contains('auto')),
      );
      expect(TranslationLanguage.fromCode('zh')!.nativeName, '简体中文');
      expect(TranslationLanguage.fromCode('nope'), isNull);
      expect(TranslationProvider.fromId('libre'), TranslationProvider.libre);
    });
  });

  group('TranslationService', () {
    late TranslationService service;

    setUp(() => service = TranslationService());

    test('does nothing while translation is off or the text is empty', () async {
      expect(await service.translate('hello'), isNull);
      service.updateSettings(const TranslationSettings(enabled: true));
      expect(await service.translate(''), isNull);
    });

    test('returns the original text when source and target match', () async {
      service.updateSettings(const TranslationSettings(
        enabled: true,
        sourceLanguage: 'en',
        targetLanguage: 'en',
      ));

      final result = await service.translate('hello');
      expect(result!.translatedText, 'hello');
      expect(result.sourceLanguage, 'en');
    });

    test('swapLanguages exchanges the pair and ignores auto-detect', () {
      service.updateSettings(const TranslationSettings(
        sourceLanguage: 'ja',
        targetLanguage: 'en',
      ));
      service.swapLanguages();
      expect(service.settings.sourceLanguage, 'en');
      expect(service.settings.targetLanguage, 'ja');

      service.updateSettings(const TranslationSettings(sourceLanguage: 'auto'));
      service.swapLanguages();
      expect(service.settings.sourceLanguage, 'auto');
    });

    test('detectLanguage uses script heuristics', () async {
      expect(await service.detectLanguage(''), isNull);
      expect(await service.detectLanguage('你好'), 'zh');
      expect(await service.detectLanguage('こんにちは'), 'ja');
      expect(await service.detectLanguage('안녕하세요'), 'ko');
      expect(await service.detectLanguage('مرحبا'), 'ar');
      expect(await service.detectLanguage('Привет'), 'ru');
      expect(await service.detectLanguage('hello'), 'en');
    });
  });
}
