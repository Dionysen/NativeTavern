import 'package:flutter/material.dart';

/// Faint centered watermark for an empty secondary (detail) pane.
class EmptySecondaryPane extends StatelessWidget {
  const EmptySecondaryPane({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.16),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
          ),
        ),
      ),
    );
  }
}
