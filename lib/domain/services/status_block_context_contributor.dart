import 'package:native_tavern/data/models/status_block_config.dart';
import 'package:native_tavern/domain/services/chat_generation_pipeline.dart';

/// Injects the latest built-in status snapshot into the next LLM turn.
final class StatusBlockContextContributor extends ContextContributor {
  StatusBlockContextContributor({
    required bool Function() enabled,
    required bool Function() injectIntoContext,
    required StatusBlockSnapshot? Function() latestSnapshot,
  })  : _enabled = enabled,
        _injectIntoContext = injectIntoContext,
        _latestSnapshot = latestSnapshot;

  static const contributorId = 'status_block.snapshot';

  final bool Function() _enabled;
  final bool Function() _injectIntoContext;
  final StatusBlockSnapshot? Function() _latestSnapshot;

  @override
  String get id => contributorId;

  @override
  int get order => 690;

  @override
  int get maxTokens => 500;

  @override
  Future<bool> isEnabled(ChatContextRequest request) async {
    return _enabled() && _injectIntoContext();
  }

  @override
  Future<ContextContribution> contribute(ChatContextRequest request) async {
    request.cancellationToken.throwIfCancelled();
    final snapshot = _latestSnapshot();
    if (snapshot == null || snapshot.isEmpty) {
      return ContextContribution(messages: const []);
    }
    final body = snapshot.toCompactText();
    if (body.isEmpty) {
      return ContextContribution(messages: const []);
    }
    return ContextContribution(
      placement: ContextContributionPlacement.beforeConversation,
      messages: [
        {
          'role': 'system',
          'content':
              'Current character status snapshot (keep consistent unless the '
              'scene clearly changes it):\n$body',
        },
      ],
    );
  }
}
