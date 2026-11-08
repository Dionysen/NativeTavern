import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Blocks route pop / app-exit while [canPop] is false, and runs [onIntercept]
/// for system back, predictive-back, and desktop Escape instead.
///
/// Needed for shell-tab screens where a plain [PopScope] alone may not stop
/// Android/iOS back from leaving the app, and Escape does not map to pop.
///
/// Full-screen routes (character detail, chat, …) are pushed on the root
/// navigator while shell tabs stay mounted in a nested navigator. While a
/// root overlay is up, [BackButtonListener] yields so the overlay pops first.
///
/// Important: [PopScope.canPop] always mirrors [canPop] (e.g. false inside a
/// folder). It must **not** flip to true merely because a covering route is
/// showing — that made the shell advertise itself as poppable under detail,
/// and after closing detail the next gesture back exited the app instead of
/// leaving the folder.
///
/// [BackButtonListener] stays mounted whenever a [Router] is present so
/// toggling [canPop] does not remount the child subtree (scroll jump).
class InterceptPopScope extends StatelessWidget {
  const InterceptPopScope({
    super.key,
    required this.canPop,
    required this.onIntercept,
    required this.child,
  });

  final bool canPop;
  final VoidCallback onIntercept;
  final Widget child;

  /// True when a route above this widget should receive back first.
  static bool hasCoveringRoute(BuildContext context) {
    // Shell under a root overlay, or an offstage IndexedStack tab.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return true;

    final root = Navigator.maybeOf(context, rootNavigator: true);
    final local = Navigator.maybeOf(context);
    if (root == null) return false;

    // Nested shell-tab routes stay [ModalRoute.isCurrent] under a root overlay
    // (StatefulShellRoute). Detect that via the root stack.
    if (local != null && !identical(root, local) && root.canPop()) {
      return true;
    }

    // Shell content lives on the root navigator: another root page above us.
    if (identical(root, local) && root.canPop()) return true;

    return false;
  }

  bool _shouldIntercept(BuildContext context) =>
      !canPop && !hasCoveringRoute(context);

  @override
  Widget build(BuildContext context) {
    final routerDelegate = GoRouter.maybeOf(context)?.routerDelegate;
    if (routerDelegate is Listenable) {
      return ListenableBuilder(
        listenable: routerDelegate as Listenable,
        builder: (context, _) => _buildInterceptTree(context),
      );
    }
    return _buildInterceptTree(context);
  }

  Widget _buildInterceptTree(BuildContext context) {
    final covered = hasCoveringRoute(context);
    final intercepting = !canPop && !covered;

    Widget content = PopScope(
      // Keep shell un-poppable while local state must unwind (folder /
      // selection), even if a root overlay is currently showing.
      //
      // GoRouter.popRoute skips Navigator.maybePop when the root stack has
      // only the shell, so this PopScope alone cannot stop app exit — it
      // still matters: Android predictive-back uses the shell route's
      // popDisposition (canHandlePop) to decide whether to ask Flutter.
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_shouldIntercept(context)) return;
        onIntercept();
      },
      child: child,
    );

    if (Router.maybeOf(context) != null) {
      content = BackButtonListener(
        onBackButtonPressed: () async {
          if (hasCoveringRoute(context)) return false;
          if (canPop) return false;
          onIntercept();
          return true;
        },
        child: content,
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_shouldIntercept(context)) return;
          onIntercept();
        },
      },
      child: Focus(
        canRequestFocus: intercepting,
        skipTraversal: true,
        child: content,
      ),
    );
  }
}
