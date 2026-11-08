import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/status_block_config.dart';
import 'package:native_tavern/domain/services/chat_generation_pipeline.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/domain/services/status_block_context_contributor.dart';
import 'package:native_tavern/domain/services/status_block_prompt_service.dart';
import 'package:native_tavern/presentation/providers/chat_extension_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _statusBlockConfigKey = 'status_block_config';

final statusBlockConfigProvider =
    StateNotifierProvider<StatusBlockConfigNotifier, StatusBlockConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StatusBlockConfigNotifier(prefs);
});

class StatusBlockConfigNotifier extends StateNotifier<StatusBlockConfig> {
  StatusBlockConfigNotifier(this._prefs)
      : super(StatusBlockConfig.defaultConfig) {
    _loadConfig();
  }

  final SharedPreferences _prefs;

  void _loadConfig() {
    final jsonString = _prefs.getString(_statusBlockConfigKey);
    if (jsonString != null) {
      try {
        state = StatusBlockConfig.fromJsonString(jsonString);
        return;
      } catch (_) {
        state = StatusBlockConfig.defaultConfig;
      }
    } else {
      _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    await _prefs.setString(_statusBlockConfigKey, state.toJsonString());
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _saveConfig();
  }

  Future<void> setInjectIntoContext(bool value) async {
    state = state.copyWith(injectIntoContext: value);
    await _saveConfig();
  }

  Future<void> setAutoDisableWhenCardHasStatus(bool value) async {
    state = state.copyWith(autoDisableWhenCardHasStatus: value);
    await _saveConfig();
  }

  Future<void> setPromptTemplate(String template) async {
    state = state.copyWith(promptTemplate: template);
    await _saveConfig();
  }

  Future<void> setFields(List<StatusFieldSlot> fields) async {
    final next = state.copyWith(fields: fields);
    state = next.copyWith(fields: next.normalizedFields());
    await _saveConfig();
  }

  Future<void> addField(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final fields = state.normalizedFields();
    if (fields.length >= StatusBlockConfig.maxFields) return;
    final id = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    fields.add(StatusFieldSlot(id: id, label: trimmed));
    await setFields(fields);
  }

  Future<void> removeFieldAt(int index) async {
    final fields = state.normalizedFields();
    if (index < 0 || index >= fields.length) return;
    if (fields[index].locked) return;
    fields.removeAt(index);
    await setFields(fields);
  }

  Future<void> renameFieldAt(int index, String label) async {
    final fields = state.normalizedFields();
    if (index < 0 || index >= fields.length) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final current = fields[index];
    fields[index] = current.copyWith(
      label: trimmed,
      id: current.locked
          ? current.id
          : trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
    );
    await setFields(fields);
  }

  Future<void> reorderFields(int oldIndex, int newIndex) async {
    final fields = state.normalizedFields();
    if (oldIndex < 0 || oldIndex >= fields.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    // Keep locked name first.
    if (fields[oldIndex].locked || target == 0 && fields.first.locked) {
      if (fields[oldIndex].locked) return;
      if (target == 0) target = 1;
    }
    final item = fields.removeAt(oldIndex);
    fields.insert(target.clamp(0, fields.length), item);
    await setFields(fields);
  }

  Future<void> resetToDefault() async {
    state = StatusBlockConfig.defaultConfig;
    await _saveConfig();
  }
}

class StatusBlockSessionState {
  final String? chatId;
  final StatusBlockSnapshot? snapshot;
  final bool isLoading;
  final String? error;

  const StatusBlockSessionState({
    this.chatId,
    this.snapshot,
    this.isLoading = false,
    this.error,
  });

  StatusBlockSessionState copyWith({
    String? chatId,
    StatusBlockSnapshot? snapshot,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSnapshot = false,
  }) {
    return StatusBlockSessionState(
      chatId: chatId ?? this.chatId,
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final statusBlockSessionProvider = StateNotifierProvider<
    StatusBlockSessionNotifier, StatusBlockSessionState>((ref) {
  return StatusBlockSessionNotifier(ref);
});

class StatusBlockSessionNotifier extends StateNotifier<StatusBlockSessionState> {
  StatusBlockSessionNotifier(this._ref)
      : super(const StatusBlockSessionState());

  final Ref _ref;
  int _generationToken = 0;

  void clearForUserSend() {
    _generationToken++;
    // Keep last snapshot visible while regenerating after the next reply.
    state = state.copyWith(isLoading: false, clearError: true);
  }

  void clearForChat(String chatId) {
    if (state.chatId != chatId) {
      state = StatusBlockSessionState(chatId: chatId);
    } else {
      state = state.copyWith(clearError: true);
    }
  }

  void hydrateFromMessages(List<ChatMessage> messages) {
    for (final message in messages.reversed) {
      if (message.role != MessageRole.assistant) continue;
      final snapshot = StatusBlockSnapshot.fromMetadata(message.metadata);
      if (snapshot != null) {
        state = StatusBlockSessionState(
          chatId: message.chatId,
          snapshot: snapshot,
        );
        return;
      }
    }
  }

  /// Returns the new snapshot when generation succeeds.
  Future<StatusBlockSnapshot?> generateForChat({
    required String chatId,
    required LLMConfig config,
    required List<Map<String, dynamic>> contextMessages,
    required String userName,
    List<String> sceneCharacterHints = const [],
  }) async {
    final statusConfig = _ref.read(statusBlockConfigProvider);
    if (!statusConfig.enabled) return null;

    final token = ++_generationToken;
    state = StatusBlockSessionState(
      chatId: chatId,
      snapshot: state.chatId == chatId ? state.snapshot : null,
      isLoading: true,
    );

    try {
      final systemPrompt = StatusBlockPromptService.buildSystemPrompt(
        config: statusConfig,
        userName: userName,
        sceneCharacterHints: sceneCharacterHints,
        previous: state.snapshot,
      );
      final messages = <Map<String, dynamic>>[
        ...contextMessages,
        {'role': 'system', 'content': systemPrompt},
      ];
      final llm = _ref.read(llmServiceProvider);
      final statusLlmConfig = config.copyWith(
        streamEnabled: false,
        maxTokens: ((1 + sceneCharacterHints.length) * 256).clamp(256, 2048),
      );

      final maxAttempts = 1 + StatusBlockPromptService.maxFormatRetries;
      String? lastValidationError;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final response = await llm.generateWithReasoning(
          messages,
          statusLlmConfig,
        );
        if (token != _generationToken) return null;

        final parsed = StatusBlockPromptService.parseAndValidate(
          response.content,
          statusConfig,
          userName: userName,
        );
        if (parsed.isComplete && parsed.snapshot != null) {
          state = StatusBlockSessionState(
            chatId: chatId,
            snapshot: parsed.snapshot,
            isLoading: false,
          );
          return parsed.snapshot;
        }

        lastValidationError = parsed.validationError;
        if (attempt + 1 >= maxAttempts) break;

        messages.add({'role': 'assistant', 'content': response.content});
        messages.add({
          'role': 'user',
          'content': StatusBlockPromptService.buildFormatRepairPrompt(
            config: statusConfig,
            validationError: lastValidationError ??
                'Status block JSON was incomplete or malformed.',
          ),
        });
      }

      if (token != _generationToken) return null;
      state = StatusBlockSessionState(
        chatId: chatId,
        snapshot: state.snapshot,
        isLoading: false,
        error: lastValidationError ??
            'Status block did not match the required format.',
      );
      return null;
    } catch (e) {
      if (token != _generationToken) return null;
      state = StatusBlockSessionState(
        chatId: chatId,
        snapshot: state.snapshot,
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

final statusBlockContextContributorProvider =
    Provider<StatusBlockContextContributor>((ref) {
  return StatusBlockContextContributor(
    enabled: () => ref.read(statusBlockConfigProvider).enabled,
    injectIntoContext: () =>
        ref.read(statusBlockConfigProvider).injectIntoContext,
    latestSnapshot: () => ref.read(statusBlockSessionProvider).snapshot,
  );
});

final statusBlockContextRegistrationProvider =
    Provider<ChatExtensionRegistration>((ref) {
  final registration = ref
      .watch(chatExtensionRegistryProvider)
      .registerContributor(ref.watch(statusBlockContextContributorProvider));
  ref.onDispose(registration.dispose);
  return registration;
});
