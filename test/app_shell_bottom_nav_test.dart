import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/widgets/common/app_shell.dart';

void main() {
  testWidgets('bottom nav hides on chat and character detail', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (_, __) => const Text('HOME'),
                  routes: [
                    GoRoute(
                      path: 'chat/:id',
                      builder: (_, __) => const Text('CHAT'),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.characters,
                  builder: (_, __) => const Text('CHARS'),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, __) => const Text('DETAIL'),
                    ),
                  ],
                ),
              ],
            ),
            for (final path in [
              AppRoutes.play,
              AppRoutes.aiConfig,
              AppRoutes.appearance,
              AppRoutes.settings,
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, __) => Text(path),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    router.go('/chat/1');
    await tester.pumpAndSettle();
    expect(find.text('CHAT'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    router.go('/characters/abc');
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    router.go(AppRoutes.characters);
    await tester.pumpAndSettle();
    expect(find.text('CHARS'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
