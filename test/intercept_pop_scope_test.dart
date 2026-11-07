import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/widgets/common/intercept_pop_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'system back pops root overlay instead of unwinding shell folder state',
    (tester) async {
      var interceptCount = 0;
      final rootKey = GlobalKey<NavigatorState>();

      final router = GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/characters',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => navigationShell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/characters',
                    builder: (context, state) {
                      return InterceptPopScope(
                        canPop: false,
                        onIntercept: () => interceptCount++,
                        child: Scaffold(
                          body: Center(
                            child: TextButton(
                              onPressed: () => context.push('/characters/1'),
                              child: const Text('open'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/characters/:id',
            parentNavigatorKey: rootKey,
            builder: (context, state) => const Scaffold(
              body: Text('detail'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(InterceptPopScope.hasCoveringRoute(
        tester.element(find.text('open')),
      ), isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      expect(interceptCount, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(interceptCount, 0, reason: 'must not leave folder under detail');
      expect(find.text('detail'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'system back intercepts only while route is current',
    (tester) async {
      var interceptCount = 0;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return InterceptPopScope(
                canPop: false,
                onIntercept: () => interceptCount++,
                child: const Scaffold(body: Text('shell')),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isTrue);
      expect(interceptCount, 1);
      expect(find.text('shell'), findsOneWidget);
    },
  );

  testWidgets('Escape only intercepts on the current route', (tester) async {
    var interceptCount = 0;
    final rootKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/characters',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/characters',
                  builder: (context, state) {
                    return InterceptPopScope(
                      canPop: false,
                      onIntercept: () => interceptCount++,
                      child: Scaffold(
                        body: Center(
                          child: TextButton(
                            onPressed: () => context.push('/characters/1'),
                            child: const Text('open'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/characters/:id',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const Scaffold(
            body: Text('detail'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(interceptCount, 0);
    expect(find.text('detail'), findsOneWidget);
  });
}
