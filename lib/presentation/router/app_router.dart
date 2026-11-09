import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/screens/home/home_screen.dart';
import 'package:native_tavern/presentation/screens/chat/chat_screen.dart';
import 'package:native_tavern/presentation/screens/character/character_list_screen.dart';
import 'package:native_tavern/presentation/screens/character/character_detail_screen.dart';
import 'package:native_tavern/presentation/screens/character_editor/character_editor_screen.dart';
import 'package:native_tavern/presentation/screens/settings/appearance_screen.dart';
import 'package:native_tavern/presentation/screens/settings/settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/prompt_manager_screen.dart';
import 'package:native_tavern/presentation/screens/settings/advanced_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/quick_reply_screen.dart';
import 'package:native_tavern/presentation/screens/settings/chat_choice_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/status_block_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/background_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/statistics_screen.dart';
import 'package:native_tavern/presentation/screens/settings/ai_presets_screen.dart';
import 'package:native_tavern/presentation/screens/settings/sprite_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/live2d_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/tts_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/stt_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/translation_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/image_gen_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/regex_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/variables_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/cloud_backup_screen.dart';
import 'package:native_tavern/presentation/screens/settings/logit_bias_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/cfg_scale_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/tokenizer_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/vector_storage_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/capability_diagnostics_screen.dart';
import 'package:native_tavern/presentation/screens/settings/memory_inbox_screen.dart';
import 'package:native_tavern/presentation/screens/settings/mcp_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/tool_calling_settings_screen.dart';
import 'package:native_tavern/presentation/screens/settings/storage_management_screen.dart';
import 'package:native_tavern/presentation/screens/data_bank/data_bank_screen.dart';
import 'package:native_tavern/presentation/screens/rpg/rpg_scenario_editor_screen.dart';
import 'package:native_tavern/presentation/widgets/chat/logprobs_panel.dart';
import 'package:native_tavern/presentation/screens/ai_config/ai_config_screen.dart';
import 'package:native_tavern/presentation/screens/import/import_screen.dart';
import 'package:native_tavern/presentation/screens/personas/personas_screen.dart';
import 'package:native_tavern/presentation/screens/world_info/world_info_screen.dart';
import 'package:native_tavern/presentation/screens/play/moments_screen.dart';
import 'package:native_tavern/presentation/screens/play/play_hub_screen.dart';
import 'package:native_tavern/presentation/screens/play/story_screen.dart';
import 'package:native_tavern/presentation/screens/groups/groups_screen.dart';
import 'package:native_tavern/presentation/screens/groups/group_detail_screen.dart';
import 'package:native_tavern/presentation/screens/tags/tags_screen.dart';
import 'package:native_tavern/presentation/widgets/common/app_shell.dart';
import 'package:native_tavern/presentation/widgets/common/master_detail_branch.dart';

/// Route paths
abstract class AppRoutes {
  static const home = '/';
  static const characters = '/characters';
  static const characterDetail = '/characters/:id';
  static const characterCreate = '/characters/new';
  static const characterEdit = '/characters/:id/edit';
  static const chat = '/chat/:id';
  static const settings = '/settings';
  /// Full-screen settings when opened from chat (root navigator).
  static const settingsPush = '/settings-push';
  static const appearance = '/appearance';
  /// Full-screen appearance when opened from chat (root navigator).
  static const appearancePush = '/appearance-push';
  static const aiConfig = '/ai-config';
  static const promptManager = '/prompt-manager';
  static const advancedSettings = '/advanced-settings';
  static const quickReplies = '/quick-replies';
  static const replyChoices = '/reply-choices';
  static const characterStatus = '/character-status';
  static const backgroundSettings = '/background-settings';
  static const themeSettings = '/theme-settings';
  static const statistics = '/statistics';
  static const chatStatistics = '/chat/:id/statistics';
  static const aiPresets = '/ai-presets';
  static const import_ = '/import';
  static const personas = '/personas';
  static const play = '/play';
  static const playStory = '/play/story';
  static const playMoments = '/play/moments';
  static const worldInfo = '/world-info';
  static const groups = '/groups';
  static const groupDetail = '/groups/:id';
  static const tags = '/tags';
  static const spriteSettings = '/sprite-settings';
  static const characterSprites = '/characters/:id/sprites';
  static const characterLive2D = '/characters/:id/live2d';
  static const ttsSettings = '/tts-settings';
  static const sttSettings = '/stt-settings';
  static const translationSettings = '/translation-settings';
  static const imageGenSettings = '/image-gen-settings';
  static const regexSettings = '/regex-settings';
  static const variablesSettings = '/variables-settings';
  static const backupSettings = '/backup-settings';
  static const cloudBackupSettings = '/cloud-backup-settings';
  static const logitBiasSettings = '/logit-bias-settings';
  static const cfgScaleSettings = '/cfg-scale-settings';
  static const logprobsSettings = '/logprobs-settings';
  static const tokenizerSettings = '/tokenizer-settings';
  static const vectorStorageSettings = '/vector-storage-settings';
  static const capabilityDiagnostics = '/capability-diagnostics';
  static const memoryInbox = '/memory-inbox';
  static const mcpSettings = '/mcp-settings';
  static const toolCallingSettings = '/tool-calling-settings';
  static const dataBank = '/data-bank';
  static const rpgScenarioEditor = '/rpg-scenario-editor';
  static const storageManagement = '/storage-management';

  /// These routes provide bars that can share UIKit's vertical status column.
  static bool sharesVerticalBar(Uri uri) =>
      const {home, characters, play, worldInfo, aiConfig, appearance, settings}
          .contains(uri.path) ||
      RegExp(r'^/chat/[^/]+$').hasMatch(uri.path);
}

/// Navigation keys for nested navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      // Full-screen character editors must stay on the root navigator and be
      // registered before the shell so /characters/new is not captured by :id.
      GoRoute(
        path: AppRoutes.characterCreate,
        name: 'characterCreate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CharacterEditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.characterEdit,
        name: 'characterEdit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CharacterEditorScreen(characterId: id);
        },
      ),
      // Keep shell tabs alive so switching chats ↔ characters does not
      // remount and re-decode thousands of avatar tiles.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => MasterDetailBranch(
                  primary: const HomeScreen(),
                  detail: state.uri.path == AppRoutes.home ? null : child,
                  emptyLabel:
                      AppLocalizations.of(context).emptySecondarySelectChat,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.home,
                    name: 'home',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MasterDetailPlaceholder(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.chat,
                    name: 'chat',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return NoTransitionPage(
                        child: ChatScreen(
                          chatId: id,
                          initialMessageId: state.uri.queryParameters['message'],
                          initialDraft: state.uri.queryParameters['draft'],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => MasterDetailBranch(
                  primary: const CharacterListScreen(),
                  detail:
                      state.uri.path == AppRoutes.characters ? null : child,
                  emptyLabel: AppLocalizations.of(context)
                      .emptySecondarySelectCharacter,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.characters,
                    name: 'characters',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MasterDetailPlaceholder(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.characterDetail,
                    name: 'characterDetail',
                    // Avoid treating /characters/new as a detail id if that
                    // path is ever matched here before the root create route.
                    redirect: (context, state) {
                      final id = state.pathParameters['id'];
                      if (id == 'new') return AppRoutes.characterCreate;
                      return null;
                    },
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return NoTransitionPage(
                        child: CharacterDetailScreen(characterId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => MasterDetailBranch(
                  primary: const PlayHubScreen(),
                  detail: state.uri.path == AppRoutes.play ? null : child,
                  emptyLabel:
                      AppLocalizations.of(context).emptySecondarySelectPlay,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.play,
                    name: 'play',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MasterDetailPlaceholder(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.playMoments,
                    name: 'playMoments',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MomentsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.playStory,
                    name: 'playStory',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: StoryScreen(
                        initialChatId: state.uri.queryParameters['chat'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.worldInfo,
                    name: 'worldInfo',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: WorldInfoScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.dataBank,
                    name: 'dataBank',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: DataBankScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => MasterDetailBranch(
                  primary: const AIConfigScreen(),
                  detail: state.uri.path == AppRoutes.aiConfig ? null : child,
                  emptyLabel:
                      AppLocalizations.of(context).emptySecondarySelectAiConfig,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.aiConfig,
                    name: 'aiConfig',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MasterDetailPlaceholder(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.advancedSettings,
                    name: 'advancedSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: AdvancedSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.promptManager,
                    name: 'promptManager',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: PromptManagerScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.aiPresets,
                    name: 'aiPresets',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: AIPresetsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => MasterDetailBranch(
                  primary: const AppearanceScreen(),
                  detail:
                      state.uri.path == AppRoutes.appearance ? null : child,
                  emptyLabel: AppLocalizations.of(context)
                      .emptySecondarySelectAppearance,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.appearance,
                    name: 'appearance',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MasterDetailPlaceholder(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.backgroundSettings,
                    name: 'backgroundSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: BackgroundSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.themeSettings,
                    name: 'themeSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: AppearanceScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => MasterDetailBranch(
                  primary: const SettingsScreen(),
                  detail: state.uri.path == AppRoutes.settings ? null : child,
                  emptyLabel:
                      AppLocalizations.of(context).emptySecondarySelectSetting,
                ),
                routes: [
                  GoRoute(
                    path: AppRoutes.settings,
                    name: 'settings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MasterDetailPlaceholder(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.personas,
                    name: 'personas',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: PersonasScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.quickReplies,
                    name: 'quickReplies',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: QuickReplyScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.replyChoices,
                    name: 'replyChoices',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: ChatChoiceSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.characterStatus,
                    name: 'characterStatus',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: StatusBlockSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.memoryInbox,
                    name: 'memoryInbox',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: MemoryInboxScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.rpgScenarioEditor,
                    name: 'rpgScenarioEditor',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: RpgScenarioEditorScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.ttsSettings,
                    name: 'ttsSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: TTSSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.sttSettings,
                    name: 'sttSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: STTSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.translationSettings,
                    name: 'translationSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: TranslationSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.imageGenSettings,
                    name: 'imageGenSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: ImageGenSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.spriteSettings,
                    name: 'spriteSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: SpriteSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.capabilityDiagnostics,
                    name: 'capabilityDiagnostics',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: CapabilityDiagnosticsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.mcpSettings,
                    name: 'mcpSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: McpSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.toolCallingSettings,
                    name: 'toolCallingSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: ToolCallingSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.storageManagement,
                    name: 'storageManagement',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: StorageManagementScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.regexSettings,
                    name: 'regexSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: RegexSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.variablesSettings,
                    name: 'variablesSettings',
                    pageBuilder: (context, state) {
                      final chatId = state.uri.queryParameters['chatId'];
                      return NoTransitionPage(
                        child: VariablesSettingsScreen(chatId: chatId),
                      );
                    },
                  ),
                  GoRoute(
                    path: AppRoutes.logitBiasSettings,
                    name: 'logitBiasSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: LogitBiasSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.cfgScaleSettings,
                    name: 'cfgScaleSettings',
                    pageBuilder: (context, state) {
                      final characterId =
                          state.uri.queryParameters['characterId'];
                      final chatId = state.uri.queryParameters['chatId'];
                      return NoTransitionPage(
                        child: CFGScaleSettingsScreen(
                          characterId: characterId,
                          chatId: chatId,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: AppRoutes.tokenizerSettings,
                    name: 'tokenizerSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: TokenizerSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.vectorStorageSettings,
                    name: 'vectorStorageSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: VectorStorageSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.statistics,
                    name: 'statistics',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: StatisticsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.cloudBackupSettings,
                    name: 'cloudBackupSettings',
                    pageBuilder: (context, state) => const NoTransitionPage(
                      child: CloudBackupScreen(),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.backupSettings,
                    name: 'backupSettings',
                    redirect: (context, state) =>
                        AppRoutes.cloudBackupSettings,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes (outside shell)
      GoRoute(
        path: AppRoutes.import_,
        name: 'import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsPush,
        name: 'settingsPush',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.appearancePush,
        name: 'appearancePush',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatStatistics,
        name: 'chatStatistics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StatisticsScreen(chatId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.groups,
        name: 'groups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupDetail,
        name: 'groupDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.tags,
        name: 'tags',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TagsScreen(),
      ),
      GoRoute(
        path: AppRoutes.characterSprites,
        name: 'characterSprites',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Character';
          return CharacterSpritesScreen(characterId: id, characterName: name);
        },
      ),
      GoRoute(
        path: AppRoutes.characterLive2D,
        name: 'characterLive2D',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return Live2DSettingsScreen(characterId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.logprobsSettings,
        name: 'logprobsSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LogprobsSettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).pageNotFound,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(AppLocalizations.of(context).goHome),
            ),
          ],
        ),
      ),
    ),
  );
});
