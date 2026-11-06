import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_tavern/data/models/chat_choice_config.dart';
import 'package:native_tavern/domain/services/chat_choice_prompt_service.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _chatChoiceConfigKey = 'chat_choice_config';

final chatChoiceConfigProvider =
    StateNotifierProvider<ChatChoiceConfigNotifier, ChatChoiceConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChatChoiceConfigNotifier(prefs);
});

class ChatChoiceConfigNotifier extends StateNotifier<ChatChoiceConfig> {
  ChatChoiceConfigNotifier(this._prefs)
      : super(ChatChoiceConfig.defaultConfig) {
    _loadConfig();
  }

  final SharedPreferences _prefs;

  void _loadConfig() {
    final jsonString = _prefs.getString(_chatChoiceConfigKey);
    if (jsonString != null) {
      try {
        state = ChatChoiceConfig.fromJsonString(jsonString);
        return;
      } catch (_) {
        state = ChatChoiceConfig.defaultConfig;
      }
    } else {
      _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    await _prefs.setString(_chatChoiceConfigKey, state.toJsonString());
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _saveConfig();
  }

  Future<void> setChoiceCount(int count) async {
    final clamped = count.clamp(
      ChatChoiceConfig.minChoiceCount,
      ChatChoiceConfig.maxChoiceCount,
    );
    state = state.copyWith(
      choiceCount: clamped,
      slots: state.normalizedSlots(),
    );
    await _saveConfig();
  }

  Future<void> setMaxCharsPerChoice(int maxChars) async {
    state = state.copyWith(maxCharsPerChoice: maxChars.clamp(8, 500));
    await _saveConfig();
  }

  Future<void> setPromptTemplate(String template) async {
    state = state.copyWith(promptTemplate: template);
    await _saveConfig();
  }

  Future<void> updateSlotTendency(int index, String tendency) async {
    final slots = state.normalizedSlots();
    if (index < 0 || index >= slots.length) return;
    slots[index] = slots[index].copyWith(tendency: tendency);
    state = state.copyWith(slots: slots);
    await _saveConfig();
  }

  Future<void> resetToDefault() async {
    state = ChatChoiceConfig.defaultConfig;
    await _saveConfig();
  }
}

class ChatChoiceSessionState {
  final String? chatId;
  final List<String> choices;
  final bool isLoading;
  final String? error;

  const ChatChoiceSessionState({
    this.chatId,
    this.choices = const [],
    this.isLoading = false,
    this.error,
  });

  ChatChoiceSessionState copyWith({
    String? chatId,
    List<String>? choices,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatChoiceSessionState(
      chatId: chatId ?? this.chatId,
      choices: choices ?? this.choices,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final chatChoiceSessionProvider =
    StateNotifierProvider<ChatChoiceSessionNotifier, ChatChoiceSessionState>(
        (ref) {
  return ChatChoiceSessionNotifier(ref);
});

class ChatChoiceSessionNotifier extends StateNotifier<ChatChoiceSessionState> {
  ChatChoiceSessionNotifier(this._ref)
      : super(const ChatChoiceSessionState());

  final Ref _ref;
  int _generationToken = 0;

  void clearForUserSend() {
    _generationToken++;
    state = const ChatChoiceSessionState();
  }

  void clearForChat(String chatId) {
    if (state.chatId != chatId) {
      state = ChatChoiceSessionState(chatId: chatId);
    } else {
      state = state.copyWith(choices: const [], clearError: true);
    }
  }

  Future<void> generateForChat({
    required String chatId,
    required LLMConfig config,
    required List<Map<String, dynamic>> contextMessages,
  }) async {
    final choiceConfig = _ref.read(chatChoiceConfigProvider);
    if (!choiceConfig.enabled) return;

    final token = ++_generationToken;
    state = ChatChoiceSessionState(
      chatId: chatId,
      isLoading: true,
    );

    try {
      final systemPrompt = ChatChoicePromptService.buildSystemPrompt(choiceConfig);
      final messages = <Map<String, dynamic>>[
        ...contextMessages,
        {'role': 'system', 'content': systemPrompt},
      ];
      final llm = _ref.read(llmServiceProvider);
      final choiceLlmConfig = config.copyWith(
        streamEnabled: false,
        maxTokens: (choiceConfig.choiceCount * choiceConfig.maxCharsPerChoice)
            .clamp(256, 2048),
      );

      final maxAttempts = 1 + ChatChoicePromptService.maxFormatRetries;
      String? lastValidationError;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final response = await llm.generateWithReasoning(
          messages,
          choiceLlmConfig,
        );
        if (token != _generationToken) return;

        final parsed = ChatChoicePromptService.parseAndValidate(
          response.content,
          choiceConfig,
        );
        if (parsed.isComplete) {
          state = ChatChoiceSessionState(
            chatId: chatId,
            choices: parsed.choices,
            isLoading: false,
          );
          return;
        }

        lastValidationError = parsed.validationError;
        if (attempt + 1 >= maxAttempts) break;

        // Feed the bad output + specific format error back for a repair pass.
        messages.add({'role': 'assistant', 'content': response.content});
        messages.add({
          'role': 'user',
          'content': ChatChoicePromptService.buildFormatRepairPrompt(
            config: choiceConfig,
            validationError: lastValidationError ??
                'Reply choices were incomplete or malformed.',
          ),
        });
      }

      if (token != _generationToken) return;
      state = ChatChoiceSessionState(
        chatId: chatId,
        isLoading: false,
        error: lastValidationError ??
            'Reply choices did not match the required format.',
      );
    } catch (e) {
      if (token != _generationToken) return;
      state = ChatChoiceSessionState(
        chatId: chatId,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
