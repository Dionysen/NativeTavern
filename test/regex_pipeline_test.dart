import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/domain/services/chat_regex_facade.dart';
import 'package:native_tavern/domain/services/regex_service.dart';

RegexScript _script({
  required String name,
  required String find,
  required String replace,
  bool markdownOnly = false,
  bool promptOnly = false,
  List<RegexPlacement> placement = const [RegexPlacement.aiOutput],
}) {
  final now = DateTime.utc(2026, 1, 1);
  return RegexScript(
    id: name,
    scriptName: name,
    findRegex: find,
    replaceString: replace,
    placement: placement,
    markdownOnly: markdownOnly,
    promptOnly: promptOnly,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final service = RegexService.instance;

  group('getRegexedString flag matrix (ST OR semantics)', () {
    const raw = 'STATUS:hp=10';

    test('neither flag: persist only', () {
      final scripts = [
        _script(
          name: 'persist',
          find: r'STATUS:\w+=\d+',
          replace: 'CLEAN',
        ),
      ];

      expect(
        service.getRegexedString(raw, RegexPlacement.aiOutput, scripts),
        'CLEAN',
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isMarkdown: true,
        ),
        raw,
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isPrompt: true,
        ),
        raw,
      );
    });

    test('markdownOnly: display only', () {
      final scripts = [
        _script(
          name: 'md',
          find: r'STATUS:\w+=\d+',
          replace: 'BAR',
          markdownOnly: true,
        ),
      ];

      expect(
        service.getRegexedString(raw, RegexPlacement.aiOutput, scripts),
        raw,
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isMarkdown: true,
        ),
        'BAR',
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isPrompt: true,
        ),
        raw,
      );
    });

    test('promptOnly: prompt only', () {
      final scripts = [
        _script(
          name: 'prompt',
          find: r'STATUS:\w+=\d+',
          replace: 'STRIPPED',
          promptOnly: true,
        ),
      ];

      expect(
        service.getRegexedString(raw, RegexPlacement.aiOutput, scripts),
        raw,
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isMarkdown: true,
        ),
        raw,
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isPrompt: true,
        ),
        'STRIPPED',
      );
    });

    test('both flags: display OR prompt, never persist', () {
      final scripts = [
        _script(
          name: 'dual',
          find: r'STATUS:\w+=\d+',
          replace: 'UI',
          markdownOnly: true,
          promptOnly: true,
        ),
      ];

      expect(
        service.getRegexedString(raw, RegexPlacement.aiOutput, scripts),
        raw,
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isMarkdown: true,
        ),
        'UI',
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isPrompt: true,
        ),
        'UI',
      );
      expect(
        service.getRegexedString(
          raw,
          RegexPlacement.aiOutput,
          scripts,
          isMarkdown: true,
          isPrompt: true,
        ),
        'UI',
      );
    });
  });

  group('capture group replacement', () {
    test(r'$10 is not eaten by $1', () {
      final now = DateTime.utc(2026, 1, 1);
      final script = RegexScript(
        id: 'cap',
        scriptName: 'cap',
        // 10 capture groups: g1..g10
        findRegex: r'(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)',
        replaceString: r'$10-$1',
        placement: const [RegexPlacement.aiOutput],
        createdAt: now,
        updatedAt: now,
      );

      expect(
        service.runRegexScript(script, 'abcdefghij'),
        'j-a',
      );
    });
  });

  group('ChatRegexFacade', () {
    test('disabled is identity for all paths', () {
      final scripts = [
        _script(
          name: 'md',
          find: 'foo',
          replace: 'bar',
          markdownOnly: true,
        ),
      ];
      final facade = ChatRegexFacade(
        service: service,
        scripts: scripts,
        enabled: false,
      );

      const text = 'foo status';
      expect(
        facade.applyForDisplay(
          text,
          placement: RegexPlacement.aiOutput,
          depth: 0,
        ),
        text,
      );
      expect(
        facade.applyForPrompt(
          text,
          placement: RegexPlacement.aiOutput,
          depth: 0,
        ),
        text,
      );
      expect(
        facade.applyForPersist(
          text,
          placement: RegexPlacement.aiOutput,
        ),
        text,
      );
    });

    test('empty scripts is identity', () {
      final facade = ChatRegexFacade(
        service: service,
        scripts: const [],
        enabled: true,
      );
      const text = 'unchanged';
      expect(
        facade.applyForDisplay(
          text,
          placement: RegexPlacement.aiOutput,
          depth: 0,
        ),
        text,
      );
    });

    test('display path uses markdown scripts without mutating persist semantics',
        () {
      final scripts = [
        _script(
          name: 'md',
          find: 'SECRET',
          replace: 'VISIBLE',
          markdownOnly: true,
        ),
      ];
      final facade = ChatRegexFacade(
        service: service,
        scripts: scripts,
      );

      expect(
        facade.applyForDisplay(
          'SECRET',
          placement: RegexPlacement.aiOutput,
          depth: 0,
        ),
        'VISIBLE',
      );
      expect(
        facade.applyForPersist(
          'SECRET',
          placement: RegexPlacement.aiOutput,
        ),
        'SECRET',
      );
    });
  });
}
