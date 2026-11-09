import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_caption.dart';

void main() {
  testWidgets('caption stays off until the window runner enables it',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopCaptionHost(
          child: Scaffold(
            body: Text('list'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('list'), findsOneWidget);
    expect(DesktopCaptionScope.isActive(tester.element(find.text('list'))),
        isFalse);
    expect(find.byTooltip('Minimize'), findsNothing);
    expect(find.byTooltip('最小化'), findsNothing);
  });

  testWidgets('scope exposes title-bar metrics when forced active',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopCaptionScope(
          active: true,
          titleBarHeight: 52,
          leadingInset: 78,
          child: Scaffold(body: Text('chrome')),
        ),
      ),
    );

    final ctx = tester.element(find.text('chrome'));
    expect(DesktopCaptionScope.isActive(ctx), isTrue);
    expect(DesktopCaptionScope.titleBarHeightOf(ctx), 52);
    expect(DesktopCaptionScope.leadingInsetOf(ctx), 78);
  });
}
