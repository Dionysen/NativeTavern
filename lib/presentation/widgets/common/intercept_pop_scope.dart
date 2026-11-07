import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Blocks route pop / app-exit while [canPop] is false, and runs [onIntercept]
/// for system back, predictive-back, and desktop Escape instead.
///
/// Needed for shell-tab screens where a plain [PopScope] alone may not stop
/// Android/iOS back from leaving the app, and Escape does not map to pop.
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

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!canPop) onIntercept();
        },
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: BackButtonListener(
          onBackButtonPressed: () async {
            if (canPop) return false;
            onIntercept();
            return true;
          },
          child: PopScope(
            canPop: canPop,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop || canPop) return;
              onIntercept();
            },
            child: child,
          ),
        ),
      ),
    );
  }
}
