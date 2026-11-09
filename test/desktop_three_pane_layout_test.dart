import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/providers/desktop_layout_providers.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';
import 'package:native_tavern/presentation/widgets/common/empty_secondary_pane.dart';
import 'package:native_tavern/presentation/widgets/common/master_detail_branch.dart';

void main() {
  group('DesktopLayout', () {
    test('rail and three-pane gates', () {
      expect(DesktopLayout.useRail(599), isFalse);
      expect(DesktopLayout.useRail(600), isTrue);

      final minContent = DesktopLayout.threePaneContentMinWidth;
      expect(DesktopLayout.useThreePane(minContent - 1), isFalse);
      expect(DesktopLayout.useThreePane(minContent), isTrue);
      expect(
        minContent,
        DesktopLayout.primaryPaneMinWidth +
            DesktopLayout.secondaryPaneMinWidth +
            DesktopLayout.paneDividerWidth,
      );
    });

    test('clampPrimaryPaneWidth respects both pane mins', () {
      const content = 800.0;
      expect(
        DesktopLayout.clampPrimaryPaneWidth(
          desired: 100,
          contentWidth: content,
        ),
        DesktopLayout.primaryPaneMinWidth,
      );
      expect(
        DesktopLayout.clampPrimaryPaneWidth(
          desired: 700,
          contentWidth: content,
        ),
        content -
            DesktopLayout.secondaryPaneMinWidth -
            DesktopLayout.paneDividerWidth,
      );
      expect(
        DesktopLayout.clampPrimaryPaneWidth(
          desired: 400,
          contentWidth: content,
        ),
        400,
      );
    });
  });

  group('MasterDetailBranch', () {
    Widget harness({
      required double width,
      required Widget? detail,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: Scaffold(
              body: SizedBox(
                width: width,
                height: 800,
              child: MasterDetailBranch(
                hubPath: '/',
                primary: const Text('PRIMARY'),
                detail: detail,
                emptyLabel: 'EMPTY',
              ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('narrow width shows only primary when detail is null',
        (tester) async {
      await tester.pumpWidget(
        harness(
          width: 390,
          detail: null,
        ),
      );
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('EMPTY'), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('narrow width shows only detail when present', (tester) async {
      await tester.pumpWidget(
        harness(
          width: 500,
          detail: const Text('DETAIL'),
        ),
      );
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.text('PRIMARY'), findsNothing);
      expect(find.text('EMPTY'), findsNothing);
    });

    testWidgets('below both pane mins stays single pane even if wide-ish',
        (tester) async {
      final justUnder = DesktopLayout.threePaneContentMinWidth - 1;
      await tester.pumpWidget(
        harness(
          width: justUnder,
          detail: null,
        ),
      );
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('EMPTY'), findsNothing);
    });

    testWidgets('wide enough shows primary, divider, and empty watermark',
        (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        harness(
          width: 1100,
          detail: null,
        ),
      );
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('EMPTY'), findsOneWidget);
      expect(find.byType(EmptySecondaryPane), findsOneWidget);
    });

    testWidgets('wide enough shows primary and detail side by side',
        (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        harness(
          width: 1100,
          detail: const Text('DETAIL'),
        ),
      );
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.text('EMPTY'), findsNothing);
    });

    testWidgets('dragging divider resizes primary within mins', (tester) async {
      const width = 1100.0;
      tester.view.physicalSize = const Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 800,
                child: MasterDetailBranch(
                  hubPath: '/',
                  primary: const SizedBox.expand(
                    key: ValueKey('primary-pane'),
                    child: Text('PRIMARY'),
                  ),
                  detail: const SizedBox.expand(
                    key: ValueKey('detail-pane'),
                    child: Text('DETAIL'),
                  ),
                  emptyLabel: 'EMPTY',
                ),
              ),
            ),
          ),
        ),
      );

      final primaryBefore =
          tester.getRect(find.byKey(const ValueKey('primary-pane')));
      expect(primaryBefore.width, DesktopLayout.primaryPaneDefaultWidth);

      await tester.drag(
        find.byKey(const ValueKey('pane-resize-handle')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();

      final primaryAfter =
          tester.getRect(find.byKey(const ValueKey('primary-pane')));
      expect(primaryAfter.width, greaterThan(primaryBefore.width + 40));
      expect(
        primaryAfter.width,
        lessThanOrEqualTo(
          width -
              DesktopLayout.secondaryPaneMinWidth -
              DesktopLayout.paneDividerWidth,
        ),
      );
      expect(
        primaryAfter.width,
        greaterThanOrEqualTo(DesktopLayout.primaryPaneMinWidth),
      );
    });

    testWidgets('all branches share the same primary pane width',
        (tester) async {
      const width = 1100.0;
      tester.view.physicalSize = const Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      Widget branch(String paneKey) {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 800,
                child: MasterDetailBranch(
                  hubPath: '/',
                  primary: SizedBox.expand(
                    key: ValueKey(paneKey),
                    child: Text(paneKey),
                  ),
                  detail: const SizedBox.expand(child: Text('DETAIL')),
                  emptyLabel: 'EMPTY',
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(branch('primary-a'));
      await tester.drag(
        find.byKey(const ValueKey('pane-resize-handle')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      final widthAfterDrag =
          tester.getRect(find.byKey(const ValueKey('primary-a'))).width;
      expect(
        widthAfterDrag,
        greaterThan(DesktopLayout.primaryPaneDefaultWidth),
      );
      expect(container.read(primaryPaneWidthProvider), widthAfterDrag);

      await tester.pumpWidget(branch('primary-b'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('primary-b'))).width,
        widthAfterDrag,
      );
    });
  });
}
