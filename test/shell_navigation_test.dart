import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/router/shell_navigation.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

void main() {
  Future<GoRouter> pumpHost(
    WidgetTester tester, {
    required Size size,
    required bool threePaneScope,
  }) async {
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          builder: (context, state) => Scaffold(
            body: ThreePaneScope(
              active: threePaneScope,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.openShell('/b'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          builder: (context, state) => const Text('B'),
        ),
      ],
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return router;
  }

  testWidgets('openShell pushes in single-pane', (tester) async {
    final router = await pumpHost(
      tester,
      size: const Size(390, 800),
      threePaneScope: false,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('openShell goes in three-pane', (tester) async {
    final router = await pumpHost(
      tester,
      size: const Size(1200, 800),
      threePaneScope: true,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
