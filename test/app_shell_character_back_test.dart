import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/widgets/common/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'after closing character detail, back leaves folder instead of exiting',
    (tester) async {
      final rootKey = GlobalKey<NavigatorState>();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(characterBrowsePathProvider.notifier)
          .enterFolder('folder-a');

      final router = GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/characters',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return AppShell(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) =>
                        const Scaffold(body: Text('home')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/characters',
                    builder: (context, state) => const Scaffold(
                      body: Text('library'),
                    ),
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('library'), findsOneWidget);
      expect(container.read(characterBrowsePathProvider), ['folder-a']);

      router.push('/characters/c1');
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      // Leave detail.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
      expect(find.text('library'), findsOneWidget);
      expect(container.read(characterBrowsePathProvider), ['folder-a']);

      // Leave folder — must not exit the shell route.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(characterBrowsePathProvider), isEmpty);
      expect(find.text('library'), findsOneWidget);
    },
  );
}
