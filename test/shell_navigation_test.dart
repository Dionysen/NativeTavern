import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
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

  testWidgets('openShell goes in side navigation', (tester) async {
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

  testWidgets('bottom nav character open does not switch the shell tab',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late StatefulNavigationShell shell;
    final router = GoRouter(
      initialLocation: '/chat/1',
      routes: [
        GoRoute(
          path: AppRoutes.stackPath,
          builder: (context, state) =>
              Text('STACK ${state.uri.queryParameters['to']}'),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return Column(
              children: [
                Text('index:${navigationShell.currentIndex}'),
                Expanded(child: navigationShell),
                TextButton(
                  onPressed: () => shell.goBranch(1),
                  child: const Text('characters-tab'),
                ),
              ],
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const Text('HOME'),
                ),
                GoRoute(
                  path: '/chat/:id',
                  builder: (context, state) => TextButton(
                    onPressed: () => context.openShell('/characters/abc'),
                    child: const Text('open-character'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/characters',
                  builder: (_, __) => const Text('CHARS'),
                ),
                GoRoute(
                  path: '/characters/:id',
                  builder: (_, __) => const Text('DETAIL'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-character'));
    await tester.pumpAndSettle();

    expect(find.text('STACK /characters/abc'), findsOneWidget);
    expect(shell.currentIndex, 0);
    expect(find.text('DETAIL'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('characters-tab'));
    await tester.pumpAndSettle();

    expect(shell.currentIndex, 1);
    expect(find.text('CHARS'), findsOneWidget);
    expect(find.text('DETAIL'), findsNothing);
  });

  testWidgets('bottom stack migrates into shell when widening to side nav',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late StatefulNavigationShell shell;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: AppRoutes.stackPath,
          builder: (context, state) {
            final to = state.uri.queryParameters['to']!;
            return BottomStackSideNavMigrator(
              target: to,
              child: Text('STACK $to'),
            );
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return navigationShell;
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const Text('HOME'),
                ),
                GoRoute(
                  path: '/chat/:id',
                  builder: (_, state) => Text('CHAT ${state.pathParameters['id']}'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/characters',
                  builder: (_, __) => const Text('CHARS'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push(AppRoutes.bottomStackLocation('/chat/42'));
    await tester.pumpAndSettle();
    expect(find.text('STACK /chat/42'), findsOneWidget);
    expect(find.text('CHAT 42'), findsNothing);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('CHAT 42'), findsOneWidget);
    expect(find.text('STACK /chat/42'), findsNothing);
    expect(shell.currentIndex, 0);
    expect(router.canPop(), isFalse);
  });

  testWidgets('side nav character open switches to the characters tab',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late StatefulNavigationShell shell;
    final router = GoRouter(
      initialLocation: '/chat/1',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return navigationShell;
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const Text('HOME'),
                ),
                GoRoute(
                  path: '/chat/:id',
                  builder: (context, state) => TextButton(
                    onPressed: () => context.openShell('/characters/abc'),
                    child: const Text('open-character'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/characters',
                  builder: (_, __) => const Text('CHARS'),
                ),
                GoRoute(
                  path: '/characters/:id',
                  builder: (_, __) => const Text('DETAIL'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-character'));
    await tester.pumpAndSettle();

    expect(shell.currentIndex, 1);
    expect(find.text('DETAIL'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
