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
}
