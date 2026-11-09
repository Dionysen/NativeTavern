import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/common/app_viewport.dart';
import 'package:native_tavern/presentation/widgets/common/desktop_layout.dart';

/// Main navigation follows the system's bar edge or the available width.
class AppShell extends StatelessWidget {
  /// Preferred: keeps tab pages alive via [StatefulShellRoute.indexedStack].
  final StatefulNavigationShell? navigationShell;

  /// Test / legacy shell body when [navigationShell] is null.
  final Widget? child;

  const AppShell({
    super.key,
    this.navigationShell,
    this.child,
  }) : assert(navigationShell != null || child != null);

  @override
  Widget build(BuildContext context) {
    final body = navigationShell ?? child!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowLayout = WindowLayoutScope.maybeOf(context);
        final edge = windowLayout?.supportsVerticalBars == true
            ? windowLayout?.verticalBarEdge
            : DesktopLayout.useRail(constraints.maxWidth)
                ? VerticalBarEdge.left
                : null;
        final railWidth =
            windowLayout?.barWidth != null && windowLayout!.barWidth > 0
                ? windowLayout.barWidth
                : DesktopLayout.railWidth;
        // Native shared-bar layouts (iOS) must keep exact rail geometry; only
        // width-based desktop rails get three-pane divider/tint chrome.
        final contentWidth = edge == null
            ? constraints.maxWidth
            : constraints.maxWidth - railWidth - DesktopLayout.railDividerWidth;
        final threePane = DesktopLayout.useThreePane(contentWidth);
        final desktopThreePaneChrome =
            threePane && windowLayout?.supportsVerticalBars != true;
        final showBottomNav = edge == null &&
            AppRoutes.isShellTabHub(GoRouterState.of(context).uri);
        final scheme = Theme.of(context).colorScheme;
        final dividerColor =
            Theme.of(context).dividerColor.withValues(alpha: 0.5);
        return Scaffold(
          // Keep the routed child in the same element slot as bars move.
          body: Row(
            textDirection: TextDirection.ltr,
            children: [
              SizedBox(
                width: edge == VerticalBarEdge.left ? railWidth : 0,
                child: edge == VerticalBarEdge.left
                    ? ColoredBox(
                        color: desktopThreePaneChrome
                            ? scheme.surfaceContainerLowest
                            : scheme.surface,
                        child: _AppNavigation(
                          vertical: true,
                          navigationShell: navigationShell,
                        ),
                      )
                    : null,
              ),
              if (desktopThreePaneChrome && edge == VerticalBarEdge.left)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: dividerColor,
                ),
              Expanded(child: body),
              if (desktopThreePaneChrome && edge == VerticalBarEdge.right)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: dividerColor,
                ),
              SizedBox(
                width: edge == VerticalBarEdge.right ? railWidth : 0,
                child: edge == VerticalBarEdge.right
                    ? ColoredBox(
                        color: desktopThreePaneChrome
                            ? scheme.surfaceContainerLowest
                            : scheme.surface,
                        child: _AppNavigation(
                          vertical: true,
                          navigationShell: navigationShell,
                        ),
                      )
                    : null,
              ),
            ],
          ),
          bottomNavigationBar: showBottomNav
              ? _AppNavigation(
                  vertical: false,
                  navigationShell: navigationShell,
                )
              : null,
        );
      },
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
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/characters')) {
      return 1;
    }
    if (location.startsWith('/play') || location.startsWith('/world-info')) {
      return 2;
    }
    if (location.startsWith('/ai-config')) {
      return 3;
    }
    if (location.startsWith('/appearance')) {
      return 4;
    }
    if (location.startsWith('/settings')) {
      return 5;
    }
    return 0;
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
    return Padding(
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
                          88 *
                          MediaQuery.textScalerOf(context).scale(1) +
                      16),
              child: NavigationRail(
                minWidth:
                    sharedBar ? layout.barWidth : DesktopLayout.railWidth,
                backgroundColor: Colors.transparent,
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
                      label: Text(
                        destination.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
