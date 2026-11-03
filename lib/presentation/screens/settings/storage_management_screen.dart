import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/domain/services/storage_governance_service.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/storage_governance_providers.dart';
import 'package:native_tavern/presentation/widgets/settings/settings_widgets.dart';
import 'package:path/path.dart' as path;

class StorageManagementScreen extends ConsumerStatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  ConsumerState<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState
    extends ConsumerState<StorageManagementScreen> {
  final Set<String> _selectedPaths = <String>{};
  Set<String> _knownCandidatePaths = const <String>{};
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(storageSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageManagement),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _working ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StorageError(
          message: error.toString(),
          retryLabel: l10n.retry,
          onRetry: _working ? null : _refresh,
        ),
        data: (value) => _buildSnapshot(context, value),
      ),
    );
  }

  Widget _buildSnapshot(BuildContext context, StorageSnapshot snapshot) {
    final l10n = AppLocalizations.of(context);
    final candidatePaths =
        snapshot.cleanupCandidates.map((candidate) => candidate.path).toSet();
    if (!_sameSet(candidatePaths, _knownCandidatePaths)) {
      _selectedPaths.removeWhere((item) => !candidatePaths.contains(item));
      _selectedPaths.addAll(candidatePaths.difference(_knownCandidatePaths));
      _knownCandidatePaths = candidatePaths;
    }
    final allSelected = candidatePaths.isNotEmpty &&
        _selectedPaths.length == candidatePaths.length;
    final service = ref.watch(storageGovernanceServiceProvider).valueOrNull;

    final categories = StorageCategory.values.toList();
    return SettingsPageBody(
      key: const Key('storage-management-list'),
      children: [
        SettingsSection(
          icon: Icons.storage_outlined,
          title: l10n.storageManagement,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        snapshot.exceedsQuota
                            ? Icons.warning_amber_rounded
                            : Icons.storage_outlined,
                        color: snapshot.exceedsQuota
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.storageUsedOfQuota(
                            _formatBytes(snapshot.totalBytes),
                            _formatBytes(snapshot.quotaBytes),
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    key: const Key('storage-quota-progress'),
                    value: snapshot.quotaFraction,
                    color: snapshot.exceedsQuota
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.exceedsQuota
                        ? l10n.storageQuotaWarning
                        : l10n.storageWithinQuota,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (snapshot.unreadablePaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.storageScanIncomplete(
                          snapshot.unreadablePaths.length),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          icon: Icons.folder_outlined,
          title: l10n.storageManagement,
          children: [
            for (var i = 0; i < categories.length; i++)
              _CategoryTile(
                usage: snapshot.categories[categories[i]]!,
                title: _categoryLabel(l10n, categories[i]),
                showDivider: i != categories.length - 1,
              ),
          ],
        ),
        SettingsSection(
          icon: Icons.cleaning_services_outlined,
          title: l10n.storageCleanupCandidates,
          children: [
            if (candidatePaths.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _working
                      ? null
                      : () => setState(() {
                            if (allSelected) {
                              _selectedPaths.clear();
                            } else {
                              _selectedPaths.addAll(candidatePaths);
                            }
                          }),
                  child: Text(
                    allSelected
                        ? l10n.storageClearSelection
                        : l10n.storageSelectAll,
                  ),
                ),
              ),
            if (snapshot.cleanupCandidates.isEmpty)
              SettingsListTile(
                icon: Icons.check_circle_outline,
                title: l10n.storageNoCleanupCandidates,
                showDivider: false,
              )
            else ...[
              for (var i = 0; i < snapshot.cleanupCandidates.length; i++)
                SettingsListTile(
                  key: ValueKey(
                      'storage-candidate-${snapshot.cleanupCandidates[i].path}'),
                  icon: _categoryIcon(snapshot.cleanupCandidates[i].category),
                  title: path.basename(snapshot.cleanupCandidates[i].path),
                  subtitle:
                      '${_cleanupReason(l10n, snapshot.cleanupCandidates[i].reason)}\n'
                      '${_displayPath(snapshot.cleanupCandidates[i].path, service?.dataRoot.path)}',
                  showDivider: true,
                  onTap: _working
                      ? null
                      : () => setState(() {
                            final p = snapshot.cleanupCandidates[i].path;
                            if (_selectedPaths.contains(p)) {
                              _selectedPaths.remove(p);
                            } else {
                              _selectedPaths.add(p);
                            }
                          }),
                  trailing: Checkbox(
                    value: _selectedPaths
                        .contains(snapshot.cleanupCandidates[i].path),
                    onChanged: _working
                        ? null
                        : (selected) => setState(() {
                              final p = snapshot.cleanupCandidates[i].path;
                              if (selected ?? false) {
                                _selectedPaths.add(p);
                              } else {
                                _selectedPaths.remove(p);
                              }
                            }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton.icon(
                  key: const Key('storage-clean-selected'),
                  onPressed: _working || _selectedPaths.isEmpty
                      ? null
                      : () => _reviewCleanup(snapshot),
                  icon: _working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services_outlined),
                  label: Text(l10n.storageCleanSelected),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(storageSnapshotProvider);
    try {
      await ref.read(storageSnapshotProvider.future);
    } catch (_) {
      // The provider error state renders the failure and retry action.
    }
  }

  Future<void> _reviewCleanup(StorageSnapshot snapshot) async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = await ref.read(storageGovernanceServiceProvider.future);
      final plan = service.createCleanupPlan(
        snapshot,
        selectedPaths: Set.of(_selectedPaths),
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.storageCleanupReviewTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.storageCleanupReviewBody(
                  plan.entries.length,
                  plan.fileCount,
                  _formatBytes(plan.bytes),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.storageCleanupRecoverableHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('storage-confirm-cleanup'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.storageCleanSelected),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _working = true);
      final receipt = await service.clean(service.confirmCleanup(plan));
      if (!mounted) {
        await receipt.commit();
        return;
      }
      final closedReason = await ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Text(l10n.storageCleanupMoved(receipt.movedCount)),
              action: SnackBarAction(
                label: l10n.storageUndo,
                onPressed: () {},
              ),
            ),
          )
          .closed;
      if (closedReason == SnackBarClosedReason.action) {
        await receipt.restore();
        if (mounted) _showMessage(l10n.storageCleanupRestored);
      } else {
        await receipt.commit();
        if (mounted) _showMessage(l10n.storageCleanupCompleted);
      }
    } catch (error) {
      if (mounted) _showMessage(l10n.storageCleanupFailed(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _working = false);
        await _refresh();
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryTile extends StatelessWidget {
  final StorageCategoryUsage usage;
  final String title;
  final bool showDivider;

  const _CategoryTile({
    required this.usage,
    required this.title,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      l10n.storageFilesCount(usage.fileCount),
      if (usage.reclaimableCount > 0)
        l10n.storageReclaimable(_formatBytes(usage.reclaimableBytes)),
    ].join('  |  ');
    return SettingsListTile(
      icon: _categoryIcon(usage.category),
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      trailing: Text(
        _formatBytes(usage.bytes),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _StorageError extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  const _StorageError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(StorageCategory category) => switch (category) {
      StorageCategory.live2d => Icons.view_in_ar_outlined,
      StorageCategory.attachments => Icons.attach_file,
      StorageCategory.dataBank => Icons.library_books_outlined,
      StorageCategory.audio => Icons.graphic_eq,
      StorageCategory.cache => Icons.cached,
    };

String _categoryLabel(AppLocalizations l10n, StorageCategory category) =>
    switch (category) {
      StorageCategory.live2d => l10n.storageCategoryLive2d,
      StorageCategory.attachments => l10n.storageCategoryAttachments,
      StorageCategory.dataBank => l10n.storageCategoryDataBank,
      StorageCategory.audio => l10n.storageCategoryAudio,
      StorageCategory.cache => l10n.storageCategoryCache,
    };

String _cleanupReason(
  AppLocalizations l10n,
  StorageCleanupReason reason,
) =>
    switch (reason) {
      StorageCleanupReason.interruptedTemporaryData =>
        l10n.storageReasonInterruptedTemporary,
      StorageCleanupReason.missingDatabaseReference =>
        l10n.storageReasonMissingDatabaseReference,
      StorageCleanupReason.interruptedDocumentCleanup =>
        l10n.storageReasonInterruptedDocumentCleanup,
      StorageCleanupReason.missingFileReference =>
        l10n.storageReasonMissingFileReference,
      StorageCleanupReason.expiredTransientData =>
        l10n.storageReasonExpiredTransient,
      StorageCleanupReason.expiredSynthesizedAudio =>
        l10n.storageReasonExpiredAudio,
    };

String _displayPath(String value, String? dataRoot) {
  if (dataRoot != null && path.isWithin(dataRoot, value)) {
    return path.relative(value, from: dataRoot);
  }
  return path.join(path.basename(path.dirname(value)), path.basename(value));
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KiB';
  final mib = kib / 1024;
  if (mib < 1024) return '${mib.toStringAsFixed(1)} MiB';
  return '${(mib / 1024).toStringAsFixed(1)} GiB';
}

bool _sameSet(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}
