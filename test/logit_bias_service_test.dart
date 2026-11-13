import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/logit_bias.dart';
import 'package:native_tavern/domain/services/logit_bias_service.dart';

void main() {
  late LogitBiasService service;

  setUp(() => service = LogitBiasService());

  List<int> tokenize(String text, TokenizerType type) {
    return text.codeUnits;
  }

  LogitBiasEntry entry(String text, {double value = 2, bool enabled = true}) {
    return LogitBiasEntry(
      id: text,
      text: text,
      value: value,
      enabled: enabled,
    );
  }

  group('parseEntry', () {
    test('classifies plain text, verbatim braces, and token id arrays', () {
      expect(service.parseEntry(entry('hello')).processedText, ' hello');
      expect(
        service.parseEntry(entry('hello')).format,
        LogitBiasInputFormat.text,
      );

      final verbatim = service.parseEntry(entry('{Hello}'));
      expect(verbatim.format, LogitBiasInputFormat.verbatim);
      expect(verbatim.processedText, 'Hello');

      final ids = service.parseEntry(entry('[1, 2]'));
      expect(ids.format, LogitBiasInputFormat.tokenIds);
      expect(ids.tokenIds, [1, 2]);

      expect(
        service.parseEntry(entry('[not json]')).format,
        LogitBiasInputFormat.text,
      );
    });
  });

  group('processEntries', () {
    test('skips disabled and blank entries and caches the result', () {
      final entries = [
        entry('hi', value: 3),
        entry('skip', enabled: false),
        entry('   '),
        entry('[4, 5]', value: -1),
      ];

      final first = service.processEntries(entries, TokenizerType.openai, tokenize);
      final second = service.processEntries(entries, TokenizerType.openai, tokenize);

      expect(identical(first, second), isTrue);
      expect(first, hasLength(2));
      expect(first.first['bias'], 3);
      expect(first.first['tokens'], ' hi'.codeUnits);
      expect(first.last['tokens'], [4, 5]);

      service.clearCache();
      final third = service.processEntries(entries, TokenizerType.openai, tokenize);
      expect(identical(first, third), isFalse);
    });

    test('OpenAI format uses string token keys and Anthropic stays empty', () {
      final entries = [entry('{A}', value: 1.5)];
      expect(
        service.toOpenAIFormat(entries, tokenize),
        {'${'A'.codeUnitAt(0)}': 1.5},
      );
      expect(service.toAnthropicFormat(entries, tokenize), isEmpty);
    });
  });

  group('validateEntry', () {
    test('rejects out-of-range bias and bad token arrays', () {
      final extreme = service.validateEntry(entry('hi', value: 101));
      expect(extreme.isValid, isFalse);
      expect(extreme.errors, isNotEmpty);

      final warning = service.validateEntry(entry('hi', value: 20));
      expect(warning.isValid, isTrue);
      expect(warning.warnings, isNotEmpty);

      final blank = service.validateEntry(entry('  '));
      expect(blank.warnings, contains('Empty text will be ignored'));

      final mixed = service.validateEntry(entry('["a", 1]'));
      expect(mixed.isValid, isFalse);

      final negative = service.validateEntry(entry('[1, -2]'));
      expect(negative.errors, contains('Token IDs must be non-negative'));

      final broken = service.validateEntry(entry('[oops]'));
      expect(broken.errors, contains('Invalid JSON array format for token IDs'));
    });
  });
}
