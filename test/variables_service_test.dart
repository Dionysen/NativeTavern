import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/variables_service.dart';

void main() {
  final service = VariablesService.instance;

  tearDown(() {
    service.clearLocalVariables('chat-a');
    service.clearLocalVariables('chat-b');
  });

  test('local macros stay inside one chat', () async {
    final rendered = await service.processVariableMacros(
      '{{setvar::hp::3}}HP {{getvar::hp}}',
      chatId: 'chat-a',
    );

    expect(rendered, 'HP 3');
    expect(service.getLocalVariable('chat-a', 'hp'), 3);
    expect(service.getLocalVariable('chat-b', 'hp'), '');
    expect(
      service.exportLocalVariablesToMetadata('chat-a'),
      {'variables': {'hp': '3'}},
    );
  });

  test('incvar and addvar update the stored number', () async {
    await service.processVariableMacros(
      '{{setvar::score::2}}{{incvar::score}}',
      chatId: 'chat-a',
    );
    expect(service.getLocalVariable('chat-a', 'score'), 3);

    final added = service.addLocalVariable('chat-a', 'score', 2);
    expect(added, 5);
    expect(service.decrementLocalVariable('chat-a', 'score'), 4);
  });

  test('an empty variable name is rejected', () {
    expect(
      () => service.setLocalVariable('chat-a', '', 'x'),
      throwsArgumentError,
    );
  });

  test('missing metadata loads nothing and a chat can be cleared', () {
    service.loadLocalVariablesFromMetadata('chat-a', {
      'variables': {'name': 'Ada'},
    });
    expect(service.resolveVariable('name', chatId: 'chat-a'), 'Ada');
    expect(service.resolveVariable('missing', chatId: 'chat-a'), 'missing');

    service.loadLocalVariablesFromMetadata('chat-b', null);
    expect(service.getAllLocalVariables('chat-b'), isEmpty);

    service.clearLocalVariables('chat-a');
    expect(service.existsLocalVariable('chat-a', 'name'), isFalse);
    expect(service.exportLocalVariablesToMetadata('chat-a'), isNull);
  });
}
