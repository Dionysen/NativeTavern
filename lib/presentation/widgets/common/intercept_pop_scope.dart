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
/// navigator while shell tabs stay mounted in a nested navigator. In that
/// case the tab's [ModalRoute.isCurrent] stays true, so we must also yield
/// whenever the root navigator / [GoRouter] can pop — otherwise
/// [BackButtonListener.takePriority] steals back and unwinds folder/selection
/// state underneath the overlay.
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

  /// True when a route above this shell tab should receive back first.
  static bool hasCoveringRoute(BuildContext context) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return true;

    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) return true;

    final root = Navigator.maybeOf(context, rootNavigator: true);
    final local = Navigator.maybeOf(context);
    if (root != null &&
        local != null &&
        !identical(root, local) &&
        root.canPop()) {
      return true;
    }
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
    final intercepting = _shouldIntercept(context);

    Widget content = PopScope(
      canPop: !intercepting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_shouldIntercept(context)) return;
        onIntercept();
      },
      child: child,
    );

    if (intercepting) {
      content = BackButtonListener(
        onBackButtonPressed: () async {
          if (!_shouldIntercept(context)) return false;
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
        autofocus: intercepting,
        skipTraversal: true,
        child: content,
      ),
    );
  }
}
