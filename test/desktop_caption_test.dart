import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('window buttons render at the top-right edge', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const channel = MethodChannel('native_tavern/window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    bool reportedButtons = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'immersiveTitleBar') return true;
      if (call.method == 'setCaptionButtons') reportedButtons = true;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: DesktopCaptionHost(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flutter caption buttons exist and sit at the top-right edge.
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      final closeRect = tester.getRect(find.byIcon(Icons.close));
      expect(closeRect.right, lessThanOrEqualTo(400));
      expect(closeRect.right, greaterThan(400 - DesktopCaptionMetrics.buttonWidth));

      // No native button rects should be reported — Flutter owns the clicks.
      expect(reportedButtons, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
