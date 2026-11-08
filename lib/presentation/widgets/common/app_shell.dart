import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/providers/character_folder_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/common/app_viewport.dart';
import 'package:native_tavern/presentation/widgets/common/intercept_pop_scope.dart';

/// Main navigation follows the system's bar edge or the available width.
///
/// Owns shell-level back interception for the character library. Folder /
/// selection back must be handled on this shell route — not only inside a
/// branch [IndexedStack] page — because:
/// 1. Android predictive-back uses the *root* route's popDisposition
///    (`canHandlePop`). Nested [PopScope] never marks the shell as handling
///    back, so the system finishes the Activity without asking Flutter.
/// 2. [GoRouterDelegate.popRoute] skips [Navigator.maybePop] when the root
///    stack is only the shell, so nested [PopScope.onPopInvoked] never runs.
///    [BackButtonListener] on this shell is what actually unwinds folder state.
class AppShell extends ConsumerWidget {
  /// Preferred: keeps tab pages alive via [StatefulShellRoute.indexedStack].
  final StatefulNavigationShell? navigationShell;

  /// Test / legacy shell body when [navigationShell] is null.
  final Widget? child;

  const AppShell({
    super.key,
    this.navigationShell,
    this.child,
  }) : assert(navigationShell != null || child != null);

  bool _characterLibraryBlocksExit(WidgetRef ref, int tabIndex) {
    if (tabIndex != characterLibraryShellBranchIndex) return false;
    if (ref.watch(characterLibrarySelectionActiveProvider)) return true;
    return ref.watch(characterBrowsePathProvider).isNotEmpty;
  }

  void _handleCharacterLibraryBack(WidgetRef ref) {
    if (ref.read(characterLibrarySelectionActiveProvider)) {
      ref.read(characterLibrarySelectionActiveProvider.notifier).state = false;
      return;
    }
    if (ref.read(characterBrowsePathProvider).isEmpty) return;
    ref.read(characterSearchGlobalProvider.notifier).state = false;
    ref.read(characterBrowsePathProvider.notifier).leaveFolder();
  }

  static int legacyTabIndex(String location) {
    if (location.startsWith('/characters')) return 1;
    if (location.startsWith('/play') || location.startsWith('/world-info')) {
      return 2;
    }
    if (location.startsWith('/ai-config')) return 3;
    if (location.startsWith('/appearance')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = navigationShell ?? child!;
    final tabIndex = navigationShell?.currentIndex ??
        legacyTabIndex(GoRouterState.of(context).uri.path);
    final blockExit = _characterLibraryBlocksExit(ref, tabIndex);

    return InterceptPopScope(
      canPop: !blockExit,
      onIntercept: () => _handleCharacterLibraryBack(ref),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final windowLayout = WindowLayoutScope.maybeOf(context);
          final edge = windowLayout?.supportsVerticalBars == true
              ? windowLayout?.verticalBarEdge
              : constraints.maxWidth >= 600
                  ? VerticalBarEdge.left
                  : null;
          final railWidth =
              windowLayout?.barWidth != null && windowLayout!.barWidth > 0
                  ? windowLayout.barWidth
                  : 96.0;
          return Scaffold(
            // Keep the routed child in the same element slot as bars move.
            body: Row(
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(
                  width: edge == VerticalBarEdge.left ? railWidth : 0,
                  child: edge == VerticalBarEdge.left
                      ? _AppNavigation(
                          vertical: true,
                          navigationShell: navigationShell,
                        )
                      : null,
                ),
                Expanded(child: body),
                SizedBox(
                  width: edge == VerticalBarEdge.right ? railWidth : 0,
                  child: edge == VerticalBarEdge.right
                      ? _AppNavigation(
                          vertical: true,
                          navigationShell: navigationShell,
                        )
                      : null,
                ),
              ],
            ),
            bottomNavigationBar: edge == null
                ? _AppNavigation(
                    vertical: false,
                    navigationShell: navigationShell,
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _AppNavigation extends StatelessWidget {
  const _AppNavigation({
    required this.vertical,
    required this.navigationShell,
  });

  final bool vertical;
  final StatefulNavigationShell? navigationShell;

  int _calculateSelectedIndex(BuildContext context) {
    if (navigationShell != null) {
      return navigationShell!.currentIndex;
    }
    return AppShell.legacyTabIndex(GoRouterState.of(context).uri.path);
  }

  void _onItemTapped(BuildContext context, int index) {
    final shell = navigationShell;
    if (shell != null) {
      shell.goBranch(
        index,
        initialLocation: index == shell.currentIndex,
      );
      return;
    }
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.characters);
        break;
      case 2:
        context.go(AppRoutes.play);
        break;
      case 3:
        context.go(AppRoutes.aiConfig);
        break;
      case 4:
        context.go(AppRoutes.appearance);
        break;
      case 5:
        context.go(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final l10n = AppLocalizations.of(context);

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: l10n.chats,
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: l10n.characters,
      ),
      NavigationDestination(
        icon: const Icon(Icons.explore_outlined),
        selectedIcon: const Icon(Icons.explore),
        label: l10n.playHub,
      ),
      NavigationDestination(
        icon: const Icon(Icons.auto_awesome_outlined),
        selectedIcon: const Icon(Icons.auto_awesome),
        label: l10n.aiConfig,
      ),
      NavigationDestination(
        icon: const Icon(Icons.palette_outlined),
        selectedIcon: const Icon(Icons.palette),
        label: l10n.appearanceSectionTitle,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l10n.settings,
      ),
    ];

    if (!vertical) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(context, index),
        destinations: destinations,
      );
    }
    final layout = WindowLayoutScope.maybeOf(context);
    final sharedBar = layout != null && layout.barWidth > 0;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: sharedBar ? layout.barPadding : EdgeInsets.zero,
        child: SafeArea(
          top: !sharedBar,
          bottom: !sharedBar,
          left: !sharedBar,
          right: !sharedBar,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: SizedBox(
                height: math.max(
                    constraints.maxHeight,
                    destinations.length *
                            96 *
                            MediaQuery.textScalerOf(context).scale(1) +
                        16),
                child: NavigationRail(
                  minWidth: sharedBar ? layout.barWidth : 96,
                  groupAlignment: -1,
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      _onItemTapped(context, index),
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        padding: sharedBar ? EdgeInsets.zero : null,
                        label: Text(destination.label,
                            textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
