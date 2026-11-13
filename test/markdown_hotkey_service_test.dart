import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/markdown_hotkey_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TextEditingValue value(String text, [int start = 0, int? end]) {
    return TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
    );
  }

  group('MarkdownHotkeyService.applyFormat', () {
    test('inserts markers around the caret when nothing is selected', () {
      final result = MarkdownHotkeyService.applyFormat(
        value: value('hello', 5),
        format: MarkdownFormat.bold,
      );

      expect(result.text, 'hello****');
      expect(result.selection.baseOffset, 7);
      expect(result.selection.isCollapsed, isTrue);
    });

    test('wraps a selection and removes the same markers on a second pass', () {
      final wrapped = MarkdownHotkeyService.applyFormat(
        value: value('hello', 0, 5),
        format: MarkdownFormat.italic,
      );
      expect(wrapped.text, '*hello*');
      expect(wrapped.selection.start, 1);
      expect(wrapped.selection.end, 6);

      final unwrapped = MarkdownHotkeyService.applyFormat(
        value: wrapped,
        format: MarkdownFormat.italic,
      );
      expect(unwrapped.text, 'hello');
      expect(unwrapped.selection.start, 0);
      expect(unwrapped.selection.end, 5);
    });

    test('link and code block use their own markers', () {
      final link = MarkdownHotkeyService.applyFormat(
        value: value('docs', 0, 4),
        format: MarkdownFormat.link,
      );
      expect(link.text, '[docs](url)');

      final code = MarkdownHotkeyService.applyFormat(
        value: value('x', 0, 1),
        format: MarkdownFormat.codeBlock,
      );
      expect(code.text, '```\nx\n```');
    });
  });

  test('insertElement places the snippet and moves the caret', () {
    final result = MarkdownHotkeyService.insertElement(
      value: TextEditingValue(
        text: 'ab',
        selection: const TextSelection.collapsed(offset: 1),
      ),
      element: '---\n',
      cursorOffset: -1,
    );

    expect(result.text, 'a---\nb');
    expect(result.selection.baseOffset, 4);
  });

  test('format metadata covers the shortcut set', () {
    expect(MarkdownFormat.bold.markers, ('**', '**'));
    expect(MarkdownFormat.underline.shortcutHint, '⌘U');
    expect(MarkdownFormat.horizontalRule.shortcutHint, isNull);
    expect(MarkdownFormat.bold.displayName, 'Bold');
  });

  test('a key down without a modifier is not a format shortcut', () {
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyB,
      logicalKey: LogicalKeyboardKey.keyB,
      timeStamp: Duration.zero,
    );
    expect(MarkdownHotkeyService.getFormatFromKeyEvent(event), isNull);
    expect(
      MarkdownHotkeyService.getFormatFromKeyEvent(
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyB,
          logicalKey: LogicalKeyboardKey.keyB,
          timeStamp: Duration.zero,
        ),
      ),
      isNull,
    );
  });
}
