import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/screens/character/character_library_selection.dart';

void main() {
  test('browse path stack enter leave and jump', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(characterBrowsePathProvider.notifier);
    expect(container.read(characterBrowseFolderIdProvider), isNull);

    notifier.enterFolder('a');
    notifier.enterFolder('b');
    expect(container.read(characterBrowsePathProvider), ['a', 'b']);
    expect(container.read(characterBrowseFolderIdProvider), 'b');

    notifier.leaveFolder();
    expect(container.read(characterBrowseFolderIdProvider), 'a');

    notifier.enterFolder('c');
    expect(container.read(characterBrowsePathProvider), ['a', 'c']);

    notifier.jumpToDepth(0);
    expect(container.read(characterBrowsePathProvider), ['a']);

    notifier.jumpToDepth(-1);
    expect(container.read(characterBrowsePathProvider), isEmpty);
    expect(container.read(characterBrowseFolderIdProvider), isNull);
  });

  test('selection stays on when last item is deselected', () {
    final selection = LibrarySelectionController();
    selection.enter(characterId: 'c1');
    expect(selection.selectionMode, isTrue);
    selection.toggleCharacter('c1');
    expect(selection.characterIds, isEmpty);
    expect(selection.selectionMode, isTrue);
    selection.exit();
    expect(selection.selectionMode, isFalse);
  });
}
