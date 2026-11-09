import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';
import 'package:native_tavern/presentation/widgets/common/master_detail_branch.dart';

void main() {
  testWidgets(
      'single-pane detail after go-style route still offers AppBar back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/settings/personas',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ProviderScope(
            child: MasterDetailBranch(
              hubPath: '/settings',
              primary: Scaffold(
                appBar: AppBar(title: const Text('Settings')),
                body: const Text('HUB'),
              ),
              detail: state.uri.path == '/settings' ? null : child,
              emptyLabel: 'EMPTY',
            ),
          ),
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/settings/personas',
              builder: (_, __) => ShellHubBackEnabler(
                hubPath: '/settings',
                child: Scaffold(
                  appBar: AppBar(title: const Text('Personas')),
                  body: const Text('DETAIL'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    final backRect = tester.getRect(find.byType(BackButton));
    final titleRect = tester.getRect(find.text('Personas'));
    expect(backRect.overlaps(titleRect), isFalse);
    expect(titleRect.left, greaterThan(backRect.right));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('HUB'), findsOneWidget);
    expect(find.text('DETAIL'), findsNothing);
  });

  testWidgets(
      'resize from three-pane go detail to single-pane restores back',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/settings',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ProviderScope(
            child: MasterDetailBranch(
              hubPath: '/settings',
              primary: Scaffold(
                appBar: AppBar(title: const Text('Settings')),
                body: const Text('HUB'),
              ),
              detail: state.uri.path == '/settings' ? null : child,
              emptyLabel: 'EMPTY',
            ),
          ),
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/settings/personas',
              builder: (_, __) => ShellHubBackEnabler(
                hubPath: '/settings',
                child: Scaffold(
                  appBar: AppBar(title: const Text('Personas')),
                  body: const Text('DETAIL'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final threePaneWidth = DesktopLayout.threePaneContentMinWidth + 80;
    tester.view.physicalSize = Size(threePaneWidth, 800);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/settings/personas');
    await tester.pumpAndSettle();

    expect(find.text('HUB'), findsOneWidget);
    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();

    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.text('HUB'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    final backRect = tester.getRect(find.byType(BackButton));
    final titleRect = tester.getRect(find.text('Personas'));
    expect(backRect.overlaps(titleRect), isFalse);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('HUB'), findsOneWidget);
  });

  testWidgets(
      'resize from single-pane detail to three-pane keeps the detail route',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/settings/personas',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ProviderScope(
            child: MasterDetailBranch(
              hubPath: '/settings',
              primary: Scaffold(
                appBar: AppBar(title: const Text('Settings')),
                body: const Text('HUB'),
              ),
              detail: state.uri.path == '/settings' ? null : child,
              emptyLabel: 'EMPTY',
            ),
          ),
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/settings/personas',
              builder: (_, __) => ShellHubBackEnabler(
                hubPath: '/settings',
                child: Scaffold(
                  appBar: AppBar(title: const Text('Personas')),
                  body: const Text('DETAIL'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    final threePaneWidth = DesktopLayout.threePaneContentMinWidth + 80;
    tester.view.physicalSize = Size(threePaneWidth, 800);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/settings/personas');
    expect(find.text('HUB'), findsOneWidget);
    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
