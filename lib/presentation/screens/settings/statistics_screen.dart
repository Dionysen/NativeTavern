import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/widgets/common/chrome_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_statistics.dart';
import '../../providers/statistics_providers.dart';
import '../../widgets/settings/settings_widgets.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';

/// Screen for viewing app and chat statistics
class StatisticsScreen extends ConsumerWidget {
  final String? chatId;

  const StatisticsScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(chatId != null ? l10n.chatStatistics : l10n.appStatistics),
        actions: [
          if (chatId == null)
            ChromeIconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.resetStatistics,
              onPressed: () => _showResetConfirmation(context, ref),
            ),
        ],
      ),
      body: chatId != null
          ? _ChatStatisticsView(chatId: chatId!)
          : const _AppStatisticsView(),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetStatistics),
        content: Text(l10n.resetStatisticsConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(appStatisticsProvider.notifier).reset();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.statisticsReset)),
              );
            },
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }
}

class _AppStatisticsView extends ConsumerWidget {
  const _AppStatisticsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(statisticsSummaryProvider);
    final l10n = AppLocalizations.of(context);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${l10n.error}: $e')),
      data: (summary) {
        final stats = summary.appStats;
        return SettingsPageBody(
          children: [
            SettingsSection(
              icon: Icons.dashboard,
              title: l10n.overview,
              children: [
                _StatRow(
                  icon: Icons.calendar_today,
                  label: l10n.firstUsed,
                  value: stats.appFirstUsed != null
                      ? _formatDate(stats.appFirstUsed!)
                      : l10n.unknown,
                ),
                _StatRow(
                  icon: Icons.person_outline,
                  label: l10n.totalCharacters,
                  value: summary.characterCount.toString(),
                ),
                _StatRow(
                  icon: Icons.chat_bubble_outline,
                  label: l10n.totalChats,
                  value: summary.chatCount.toString(),
                ),
                _StatRow(
                  icon: Icons.groups_outlined,
                  label: l10n.totalGroups,
                  value: summary.groupCount.toString(),
                  showDivider: false,
                ),
              ],
            ),
            SettingsSection(
              icon: Icons.message,
              title: l10n.messages,
              children: [
                _StatRow(
                  icon: Icons.forum_outlined,
                  label: l10n.totalMessages,
                  value: _formatNumber(summary.messageCount),
                ),
                _StatRow(
                  icon: Icons.auto_awesome,
                  label: l10n.totalGenerations,
                  value: _formatNumber(stats.totalGenerations),
                  showDivider: false,
                ),
              ],
            ),
            SettingsSection(
              icon: Icons.token,
              title: l10n.tokenUsage,
              children: [
                _StatRow(
                  icon: Icons.numbers,
                  label: l10n.totalTokensUsed,
                  value: _formatNumber(stats.totalTokensUsed),
                ),
                _StatRow(
                  icon: Icons.analytics_outlined,
                  label: l10n.avgTokensPerGeneration,
                  value: stats.averageTokensPerGeneration.toStringAsFixed(1),
                  showDivider: false,
                ),
              ],
            ),
            SettingsSection(
              icon: Icons.speed,
              title: l10n.performance,
              children: [
                _StatRow(
                  icon: Icons.timer_outlined,
                  label: l10n.totalGenerationTime,
                  value: _formatDuration(stats.totalGenerationTime),
                ),
                _StatRow(
                  icon: Icons.timelapse,
                  label: l10n.avgGenerationTime,
                  value: _formatDuration(stats.averageGenerationTime),
                  showDivider: false,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ChatStatisticsView extends ConsumerWidget {
  final String chatId;

  const _ChatStatisticsView({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(computedChatStatisticsProvider(chatId));

    return statsAsync.when(
      data: (stats) => _buildStatsList(context, stats),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('${AppLocalizations.of(context).error}: $e'),
      ),
    );
  }

  Widget _buildStatsList(BuildContext context, ChatStatistics stats) {
    final l10n = AppLocalizations.of(context);
    return SettingsPageBody(
      children: [
        SettingsSection(
          icon: Icons.message,
          title: l10n.messages,
          children: [
            _StatRow(
              icon: Icons.forum_outlined,
              label: l10n.totalMessages,
              value: stats.totalMessages.toString(),
            ),
            _StatRow(
              icon: Icons.person_outline,
              label: l10n.userMessages,
              value: stats.userMessages.toString(),
            ),
            _StatRow(
              icon: Icons.smart_toy_outlined,
              label: l10n.assistantMessages,
              value: stats.assistantMessages.toString(),
            ),
            _StatRow(
              icon: Icons.settings_suggest_outlined,
              label: l10n.systemMessages,
              value: stats.systemMessages.toString(),
              showDivider: false,
            ),
          ],
        ),
        SettingsSection(
          icon: Icons.timeline,
          title: l10n.timeline,
          children: [
            _StatRow(
              icon: Icons.play_arrow,
              label: l10n.firstMessage,
              value: stats.firstMessageAt != null
                  ? _formatDateTime(stats.firstMessageAt!)
                  : l10n.unknown,
            ),
            _StatRow(
              icon: Icons.stop,
              label: l10n.lastMessage,
              value: stats.lastMessageAt != null
                  ? _formatDateTime(stats.lastMessageAt!)
                  : l10n.unknown,
            ),
            _StatRow(
              icon: Icons.timelapse,
              label: l10n.chatDuration,
              value: _formatDuration(stats.chatDuration),
              showDivider: false,
            ),
          ],
        ),
        SettingsSection(
          icon: Icons.token,
          title: l10n.tokenUsage,
          children: [
            _StatRow(
              icon: Icons.numbers,
              label: l10n.totalTokens,
              value: _formatNumber(stats.totalTokensUsed),
            ),
            _StatRow(
              icon: Icons.input,
              label: l10n.promptTokens,
              value: _formatNumber(stats.promptTokens),
            ),
            _StatRow(
              icon: Icons.output,
              label: l10n.completionTokens,
              value: _formatNumber(stats.completionTokens),
            ),
            _StatRow(
              icon: Icons.analytics_outlined,
              label: l10n.avgTokensPerMessage,
              value: stats.averageTokensPerMessage.toStringAsFixed(1),
              showDivider: false,
            ),
          ],
        ),
        SettingsSection(
          icon: Icons.speed,
          title: l10n.generationPerformance,
          children: [
            _StatRow(
              icon: Icons.auto_awesome,
              label: l10n.totalGenerations,
              value: stats.generationCount.toString(),
            ),
            _StatRow(
              icon: Icons.timer_outlined,
              label: l10n.totalGenerationTime,
              value: _formatDuration(stats.totalGenerationTime),
            ),
            _StatRow(
              icon: Icons.timelapse,
              label: l10n.avgGenerationTime,
              value: _formatDuration(stats.averageGenerationTime),
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: icon,
      title: label,
      showDivider: showDivider,
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

String _formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

String _formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours % 24}h';
  } else if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  } else if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  } else if (duration.inSeconds > 0) {
    return '${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}s';
  } else if (duration.inMilliseconds > 0) {
    return '${duration.inMilliseconds}ms';
  }
  return '0s';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
