import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/theme/native_tavern_theme.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

void main() {
  test('icon button shape stays circular regardless of corner radius', () {
    expect(
      ChromeControls.iconButtonShapeFor(4),
      isA<CircleBorder>(),
    );
    expect(
      const AppShapeTheme(cornerRadius: 4).iconButtonShape,
      isA<CircleBorder>(),
    );
    expect(
      ChromeControls.labeledButtonShapeFor(4),
      isA<RoundedRectangleBorder>(),
    );
  });

  testWidgets('ChromeIconButton renders a circular IconButton', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [AppShapeTheme(cornerRadius: 4)],
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              shape: ChromeControls.iconButtonShapeFor(),
            ),
          ),
        ),
        home: Scaffold(
          body: ChromeIconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    final shape = button.style?.shape?.resolve({});
    expect(shape, isA<CircleBorder>());
  });

  testWidgets('compact density uses dense hit target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChromeIconButton(
            tooltip: 'More',
            density: ChromeIconButtonDensity.compact,
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.constraints?.minWidth, ChromeControls.buttonSize);
    expect(button.constraints?.minHeight, ChromeControls.buttonSize);
  });
}
