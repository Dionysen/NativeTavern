import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/domain/services/status_block_parser.dart';
import 'package:native_tavern/domain/services/status_block_prompt_service.dart';
import 'package:native_tavern/data/models/status_block_config.dart';

void main() {
  test('parses Status_block inside details and strips it from content', () {
    const content = '''
请选择故事线：

<details><summary>点击查看</summary>
<br>
<Status_block>
状态栏:
  用户列表:
    - 用户:
        名字: "👤 User"
        穿搭: "👗 连衣裙"
        行动: "📝 讲课"
        内心: "💭 紧张"
    - 用户:
        名字: "👤 尼克"
        穿搭: "👕 卫衣"
        行动: "📝 坐下"
</Status_block>
</details>
''';

    final parsed = StatusBlockParser.parse(content);
    expect(parsed.snapshot, isNotNull);
    expect(parsed.snapshot!.characters, hasLength(2));
    expect(parsed.snapshot!.characters.first.name, contains('User'));
    expect(parsed.snapshot!.characters.first.fields['穿搭'], contains('连衣裙'));
    expect(parsed.contentWithoutStatus, contains('请选择故事线'));
    expect(parsed.contentWithoutStatus, isNot(contains('Status_block')));
  });

  test('detects card-owned status blocks', () {
    final character = Character(
      id: 'c1',
      name: 'Test',
      createdAt: DateTime(2024),
      modifiedAt: DateTime(2024),
      firstMessage: '<Status_block>状态栏: x</Status_block>',
    );
    expect(StatusBlockParser.characterHasStatusBlock(character), isTrue);
  });

  test('prompt service parses status JSON', () {
    const raw = '''
{"characters":[{"name":"Alice","fields":{"穿搭":"coat","行动":"walk","内心":"calm","性唤起程度":"low"}}]}
''';
    final result = StatusBlockPromptService.parseAndValidate(
      raw,
      StatusBlockConfig.defaultConfig,
      userName: 'Alice',
    );
    expect(result.isComplete, isTrue);
    expect(result.snapshot!.characters.single.name, 'Alice');
    expect(result.snapshot!.characters.single.fields['穿搭'], 'coat');
  });

  test('prompt service remaps placeholder User to persona name', () {
    const raw = '''
{"characters":[{"name":"User","fields":{"穿搭":"coat","行动":"stand","内心":"calm","性唤起程度":"low"}}]}
''';
    final result = StatusBlockPromptService.parseAndValidate(
      raw,
      StatusBlockConfig.defaultConfig,
      userName: '林晚',
    );
    expect(result.isComplete, isTrue);
    expect(result.snapshot!.characters.single.name, '林晚');
  });

  test('field lines include optional per-field prompts', () {
    final prompt = StatusBlockPromptService.buildSystemPrompt(
      config: StatusBlockConfig.defaultConfig,
      userName: '林晚',
      sceneCharacterHints: const ['Alice'],
    );
    expect(prompt, contains('- 穿搭'));
    expect(prompt, isNot(contains('- 穿搭:')));
    expect(
      prompt,
      contains('- 性唤起程度: ${StatusBlockConfig.defaultArousalPrompt}'),
    );
  });

  test('legacy arousal field without prompt migrates to default', () {
    final field = StatusFieldSlot.fromJson({
      'id': 'arousal',
      'label': '性唤起程度',
      'locked': false,
    });
    expect(field.prompt, StatusBlockConfig.defaultArousalPrompt);

    final cleared = StatusFieldSlot.fromJson({
      'id': 'arousal',
      'label': '性唤起程度',
      'prompt': '',
      'locked': false,
    });
    expect(cleared.prompt, isEmpty);
  });
}
