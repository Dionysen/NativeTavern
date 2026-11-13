import 'package:flutter/widgets.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/screens/character/character_detail_screen.dart';
import 'package:native_tavern/presentation/screens/chat/chat_screen.dart';
import 'package:native_tavern/presentation/screens/data_bank/data_bank_screen.dart';
import 'package:native_tavern/presentation/screens/personas/personas_screen.dart';
import 'package:native_tavern/presentation/screens/play/moments_compose_screen.dart';
import 'package:native_tavern/presentation/screens/play/moments_screen.dart';
import 'package:native_tavern/presentation/screens/play/story_screen.dart';
import 'package:native_tavern/presentation/screens/rpg/rpg_scenario_editor_screen.dart';
import 'package:native_tavern/presentation/screens/settings/advanced_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/ai_presets_screen.dart';
import 'package:native_tavern/presentation/screens/settings/appearance_screen.dart';
import 'package:native_tavern/presentation/screens/settings/background_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/capability_diagnostics_screen.dart';
import 'package:native_tavern/presentation/screens/settings/cfg_scale_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/chat_choice_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/cloud_backup_screen.dart';
import 'package:native_tavern/presentation/screens/settings/image_gen_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/logit_bias_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/mcp_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/memory_inbox_screen.dart';
import 'package:native_tavern/presentation/screens/settings/prompt_manager_screen.dart';
import 'package:native_tavern/presentation/screens/settings/quick_reply_screen.dart';
import 'package:native_tavern/presentation/screens/settings/regex_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/sprite_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/statistics_screen.dart';
import 'package:native_tavern/presentation/screens/settings/status_block_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/storage_management_screen.dart';
import 'package:native_tavern/presentation/screens/settings/stt_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/tokenizer_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/tool_calling_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/translation_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/tts_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/variables_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/vector_storage_settings_screen.dart';

/// Full-screen page for a shell location opened from bottom navigation.
///
/// These pages used to live on the root navigator. Side navigation opens the
/// shell copy instead so the rail can switch tabs.
Widget buildBottomStackPage(String location) {
  final uri = Uri.parse(location);
  final path = uri.path;
  final query = uri.queryParameters;

  final chatId = RegExp(r'^/chat/([^/]+)$').firstMatch(path)?.group(1);
  if (chatId != null) {
    return ChatScreen(
      key: ValueKey(chatId),
      chatId: chatId,
      initialMessageId: query['message'],
      initialDraft: query['draft'],
    );
  }

  final characterId =
      RegExp(r'^/characters/([^/]+)$').firstMatch(path)?.group(1);
  if (characterId != null && characterId != 'new') {
    return CharacterDetailScreen(characterId: characterId);
  }

  return switch (path) {
    AppRoutes.playMoments => const MomentsScreen(),
    AppRoutes.playMomentsCompose => const MomentsComposeScreen(),
    AppRoutes.playStory => StoryScreen(initialChatId: query['chat']),
    AppRoutes.dataBank => const DataBankScreen(),
    AppRoutes.advancedSettings => const AdvancedSettingsScreen(),
    AppRoutes.promptManager => const PromptManagerScreen(),
    AppRoutes.aiPresets => const AIPresetsScreen(),
    AppRoutes.backgroundSettings => const BackgroundSettingsScreen(),
    AppRoutes.themeSettings => const AppearanceScreen(),
    AppRoutes.personas => const PersonasScreen(),
    AppRoutes.quickReplies => const QuickReplyScreen(),
    AppRoutes.replyChoices => const ChatChoiceSettingsScreen(),
    AppRoutes.characterStatus => const StatusBlockSettingsScreen(),
    AppRoutes.memoryInbox => const MemoryInboxScreen(),
    AppRoutes.rpgScenarioEditor => const RpgScenarioEditorScreen(),
    AppRoutes.ttsSettings => const TTSSettingsScreen(),
    AppRoutes.sttSettings => const STTSettingsScreen(),
    AppRoutes.translationSettings => const TranslationSettingsScreen(),
    AppRoutes.imageGenSettings => const ImageGenSettingsScreen(),
    AppRoutes.spriteSettings => const SpriteSettingsScreen(),
    AppRoutes.capabilityDiagnostics => const CapabilityDiagnosticsScreen(),
    AppRoutes.mcpSettings => const McpSettingsScreen(),
    AppRoutes.toolCallingSettings => const ToolCallingSettingsScreen(),
    AppRoutes.storageManagement => const StorageManagementScreen(),
    AppRoutes.regexSettings => const RegexSettingsScreen(),
    AppRoutes.variablesSettings =>
      VariablesSettingsScreen(chatId: query['chatId']),
    AppRoutes.logitBiasSettings => const LogitBiasSettingsScreen(),
    AppRoutes.cfgScaleSettings => CFGScaleSettingsScreen(
        characterId: query['characterId'],
        chatId: query['chatId'],
      ),
    AppRoutes.tokenizerSettings => const TokenizerSettingsScreen(),
    AppRoutes.vectorStorageSettings => const VectorStorageSettingsScreen(),
    AppRoutes.statistics => const StatisticsScreen(),
    AppRoutes.cloudBackupSettings || AppRoutes.backupSettings =>
      const CloudBackupScreen(),
    _ => const SizedBox.shrink(),
  };
}
