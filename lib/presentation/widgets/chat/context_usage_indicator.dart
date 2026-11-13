import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/context_usage_service.dart';
import 'package:native_tavern/presentation/providers/context_usage_providers.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';

Color contextUsageLevelColor(ContextUsageLevel level) {
  switch (level) {
    case ContextUsageLevel.low:
      return Colors.green;
    case ContextUsageLevel.medium:
      return Colors.amber;
    case ContextUsageLevel.high:
      return Colors.orange;
    case ContextUsageLevel.critical:
      return Colors.red;
  }
}

String formatContextTokenCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}

Color contextUsageComponentColor(String name) {
  final nameLower = name.toLowerCase();
  if (nameLower.contains('prompt section')) return Colors.blueGrey;
  if (nameLower.contains('system')) return Colors.blue;
  if (nameLower.contains('character') || nameLower.contains('description')) {
    return Colors.purple;
  }
  if (nameLower.contains('personality')) return Colors.deepPurple;
  if (nameLower.contains('scenario')) return Colors.indigo;
  if (nameLower.contains('persona')) return Colors.teal;
  if (nameLower.contains('world') || nameLower.contains('lore')) {
    return Colors.orange;
  }
  if (nameLower.contains('author')) return Colors.pink;
  if (nameLower.contains('example')) return Colors.brown;
  if (nameLower.contains('post-history') || nameLower.contains('jailbreak')) {
    return Colors.red;
  }
  if (nameLower.contains('nsfw')) return Colors.redAccent;
  if (nameLower.contains('chat') || nameLower.contains('history')) {
    return Colors.green;
  }
  if (nameLower.contains('summar')) return Colors.indigo;
  if (nameLower.contains('user')) return Colors.cyan;
  if (nameLower.contains('assistant')) return Colors.amber;
  if (nameLower.contains('custom')) return Colors.deepOrange;
  return Colors.blueGrey;
}

void showContextUsageDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const ContextUsageDialog(),
  );
}

/// Circular context-usage ring for the composer toolbar.
class ContextUsageComposerButton extends ConsumerWidget {
  const ContextUsageComposerButton({super.key});

  static const double _ringSize = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(contextUsageProvider);
    if (usage == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final percentage = usage.usagePercentage;
    final levelColor = contextUsageLevelColor(usage.level);
    final scheme = Theme.of(context).colorScheme;
    final trackColor = scheme.onSurface.withValues(alpha: 0.14);

    return ChromeIconButton(
      density: ChromeIconButtonDensity.compact,
      tooltip: l10n.contextUsage,
      onPressed: () => showContextUsageDialog(context),
      icon: SizedBox(
        width: _ringSize,
        height: _ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: 1,
              strokeWidth: 2.5,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(trackColor),
            ),
            CircularProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact context usage indicator for chat input area
class ContextUsageIndicator extends ConsumerWidget {
  const ContextUsageIndicator({
    super.key,
    this.enableTap = true,
    this.borderlessCompact = false,
  });

  final bool enableTap;
  final bool borderlessCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(contextUsageProvider);

    if (usage == null) {
      return const SizedBox.shrink();
    }

    final indicator = _buildCompactIndicator(context, usage);
    if (!enableTap) {
      return indicator;
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => showContextUsageDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: indicator,
      ),
    );
  }

  Widget _buildCompactIndicator(BuildContext context, ContextUsage usage) {
    final percentage = usage.usagePercentage;
    final color = contextUsageLevelColor(usage.level);
    final scheme = Theme.of(context).colorScheme;
    final trackColor = scheme.surfaceContainerHighest;
    final labelColor = borderlessCompact ? scheme.onSurfaceVariant : color;
    final mutedLabel = borderlessCompact
        ? scheme.onSurfaceVariant.withValues(alpha: 0.85)
        : color.withValues(alpha: 0.8);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 2,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(trackColor),
              ),
              CircularProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${formatContextTokenCount(usage.totalTokens)} / ${formatContextTokenCount(usage.maxContext)}',
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${percentage.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 10,
            color: mutedLabel,
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.info_outline,
          size: 12,
          color: mutedLabel,
        ),
      ],
    );

    if (borderlessCompact) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: content,
    );
  }
}

/// Detailed context usage dialog showing breakdown
class ContextUsageDialog extends ConsumerWidget {
  const ContextUsageDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(contextUsageProvider);
    final l10n = AppLocalizations.of(context);

    if (usage == null) {
      return AlertDialog(
        title: Text(l10n.contextUsage),
        content: Text(l10n.noActiveChat),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.analytics,
            color: contextUsageLevelColor(usage.level),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.contextUsage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall usage bar
            _buildOverallUsageBar(context, usage),
            const SizedBox(height: 16),
            // Usage summary
            _buildUsageSummary(context, usage, l10n),
            const SizedBox(height: 16),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
            // Component breakdown
            Text(
              l10n.breakdown,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            // Components list
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: usage.components.map((component) {
                    return _buildComponentItem(context, component, usage);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _buildOverallUsageBar(BuildContext context, ContextUsage usage) {
    final percentage = usage.usagePercentage;
    final color = contextUsageLevelColor(usage.level);
    final trackColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (usage.isOverLimit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OVER LIMIT',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsageSummary(
    BuildContext context,
    ContextUsage usage,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            context,
            l10n.totalTokens,
            formatContextTokenCount(usage.totalTokens),
            scheme.onSurface,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            context,
            l10n.maxContext,
            formatContextTokenCount(usage.maxContext),
            scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            context,
            l10n.remaining,
            formatContextTokenCount(usage.remainingTokens),
            usage.remainingTokens > 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: muted,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildComponentItem(
    BuildContext context,
    ContextComponentUsage component,
    ContextUsage usage,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final percentage = component.getPercentage(usage.maxContext);
    final hasChildren =
        component.children != null && component.children!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (!hasChildren) ...[
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  component.name,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${formatContextTokenCount(component.tokenCount)} (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Progress bar for this component
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              contextUsageComponentColor(component.name),
            ),
          ),
        ),
        // Children items if present — same left edge as parents.
        if (hasChildren)
          Column(
            children: component.children!.map((child) {
              return _buildChildItem(context, child, usage);
            }).toList(),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildChildItem(
    BuildContext context,
    ContextComponentUsage component,
    ContextUsage usage,
  ) {
    final percentage = component.getPercentage(usage.maxContext);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: contextUsageComponentColor(component.name)
                  .withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              component.name,
              style: TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${formatContextTokenCount(component.tokenCount)} (${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
