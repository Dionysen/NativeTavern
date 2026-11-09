import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';
import 'package:native_tavern/presentation/widgets/common/empty_secondary_pane.dart';
import 'package:native_tavern/presentation/widgets/common/master_detail_branch.dart';

void main() {
  group('DesktopLayout', () {
    test('rail and three-pane breakpoints', () {
      expect(DesktopLayout.useRail(599), isFalse);
      expect(DesktopLayout.useRail(600), isTrue);
      expect(DesktopLayout.useThreePane(959), isFalse);
      expect(DesktopLayout.useThreePane(960), isTrue);
    });
  });

  group('MasterDetailBranch', () {
    Widget harness({
      required double width,
      required Widget? detail,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: 800,
              child: MasterDetailBranch(
                primary: const Text('PRIMARY'),
                detail: detail,
                emptyLabel: 'EMPTY',
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
          width: 700,
          detail: const Text('DETAIL'),
        ),
      );
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.text('PRIMARY'), findsNothing);
      expect(find.text('EMPTY'), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('wide width shows primary, divider, and empty watermark',
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
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('wide width shows primary and detail side by side',
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
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });
}
