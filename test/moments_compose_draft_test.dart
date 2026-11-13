import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/moments_compose_draft_provider.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/screens/play/moments_compose_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpCompose(
    WidgetTester tester, {
    MomentsComposeDraft? initialDraft,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (initialDraft != null) ...{
        'moments_compose_draft_body': initialDraft.body,
        if (initialDraft.imagePath != null)
          'moments_compose_draft_image': initialDraft.imagePath!,
      },
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.playMomentsCompose,
      routes: [
        GoRoute(
          path: AppRoutes.playMoments,
          builder: (_, __) => const Scaffold(body: Text('MOMENTS')),
        ),
        GoRoute(
          path: AppRoutes.playMomentsCompose,
          onExit: (context) => confirmMomentsComposeLeave(context),
          builder: (_, __) => const MomentsComposeScreen(),
        ),
        GoRoute(
          path: AppRoutes.worldInfo,
          builder: (_, __) => const Scaffold(body: Text('WORLD')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('restores the single draft when opening compose', (tester) async {
    await pumpCompose(
      tester,
      initialDraft: const MomentsComposeDraft(body: 'Saved thought'),
    );
    expect(find.text('Saved thought'), findsOneWidget);
  });

  testWidgets('cancel with content can save the only draft slot', (tester) async {
    final container = await pumpCompose(tester);
    await tester.enterText(
      find.byKey(const Key('moments-compose-body')),
      'Keep me',
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Save draft?'), findsOneWidget);
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('MOMENTS'), findsOneWidget);
    expect(
      container.read(momentsComposeDraftProvider)?.body,
      'Keep me',
    );
  });

  testWidgets('cancel with content can discard the draft', (tester) async {
    final container = await pumpCompose(
      tester,
      initialDraft: const MomentsComposeDraft(body: 'Old draft'),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(container.read(momentsComposeDraftProvider), isNull);
  });

  testWidgets('leaving compose via go prompts for the draft slot',
      (tester) async {
    final container = await pumpCompose(tester);
    await tester.enterText(
      find.byKey(const Key('moments-compose-body')),
      'Switch away',
    );
    await tester.pump();

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('moments-compose-body'))),
    );
    router.go(AppRoutes.worldInfo);
    await tester.pumpAndSettle();

    expect(find.text('Save draft?'), findsOneWidget);
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('WORLD'), findsOneWidget);
    expect(
      container.read(momentsComposeDraftProvider)?.body,
      'Switch away',
    );
  });

  testWidgets('leaving compose via go can discard the draft', (tester) async {
    final container = await pumpCompose(tester);
    await tester.enterText(
      find.byKey(const Key('moments-compose-body')),
      'Throw away',
    );
    await tester.pump();

    final router = GoRouter.of(
      tester.element(find.byKey(const Key('moments-compose-body'))),
    );
    router.go(AppRoutes.worldInfo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('WORLD'), findsOneWidget);
    expect(container.read(momentsComposeDraftProvider), isNull);
  });
}
