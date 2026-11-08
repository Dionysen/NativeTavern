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

      // After closing detail, back should unwind folder state — not exit.
      expect(InterceptPopScope.hasCoveringRoute(
        tester.element(find.text('open')),
      ), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(interceptCount, 1, reason: 'back after detail should leave folder');
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

  testWidgets(
    'toggling canPop does not remount child subtree under Router',
    (tester) async {
      _MountProbe.mounts = 0;
      var canPop = true;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return InterceptPopScope(
                    canPop: canPop,
                    onIntercept: () {},
                    child: Scaffold(
                      body: const _MountProbe(),
                      floatingActionButton: FloatingActionButton(
                        onPressed: () => setState(() => canPop = !canPop),
                        child: const Icon(Icons.swap_horiz),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(_MountProbe.mounts, 1);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(canPop, isFalse);
      expect(_MountProbe.mounts, 1);
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

class _MountProbe extends StatefulWidget {
  const _MountProbe();

  static int mounts = 0;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    _MountProbe.mounts += 1;
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}
