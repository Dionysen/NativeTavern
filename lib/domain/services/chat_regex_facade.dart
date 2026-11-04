import 'package:native_tavern/data/models/regex_script.dart';
import 'package:native_tavern/domain/services/regex_service.dart';

/// Thin chat-layer wrapper around [RegexService] with SillyTavern call sites.
///
/// - [applyForDisplay]: markdownOnly / dual-flag scripts (`isMarkdown: true`)
/// - [applyForPrompt]: promptOnly / dual-flag scripts (`isPrompt: true`)
/// - [applyForPersist]: neither-flag scripts only (mutates stored content)
///
/// When [enabled] is false or [scripts] is empty, every method is identity.
class ChatRegexFacade {
  ChatRegexFacade({
    required RegexService service,
    required List<RegexScript> scripts,
    this.enabled = true,
    this.applyToUserInput = true,
    this.applyToAiOutput = true,
    this.applyToSlashCommands = false,
    this.applyToWorldInfo = false,
    this.applyToReasoning = false,
    this.characterName,
    this.userName,
  })  : _service = service,
        _scripts = scripts;

  final RegexService _service;
  final List<RegexScript> _scripts;
  final bool enabled;
  final bool applyToUserInput;
  final bool applyToAiOutput;
  final bool applyToSlashCommands;
  final bool applyToWorldInfo;
  final bool applyToReasoning;
  final String? characterName;
  final String? userName;

  bool get _active => enabled && _scripts.isNotEmpty;

  bool _placementAllowed(RegexPlacement placement) {
    return switch (placement) {
      RegexPlacement.userInput => applyToUserInput,
      RegexPlacement.aiOutput => applyToAiOutput,
      RegexPlacement.slashCommand => applyToSlashCommands,
      RegexPlacement.worldInfo => applyToWorldInfo,
      RegexPlacement.reasoning => applyToReasoning,
    };
  }

  String applyForDisplay(
    String text, {
    required RegexPlacement placement,
    required int depth,
    bool isEdit = false,
    String? characterName,
    String? userName,
  }) {
    return _apply(
      text,
      placement: placement,
      depth: depth,
      isMarkdown: true,
      isEdit: isEdit,
      characterName: characterName,
      userName: userName,
    );
  }

  String applyForPrompt(
    String text, {
    required RegexPlacement placement,
    required int depth,
    String? characterName,
    String? userName,
  }) {
    return _apply(
      text,
      placement: placement,
      depth: depth,
      isPrompt: true,
      characterName: characterName,
      userName: userName,
    );
  }

  /// Persist path: neither-flag scripts only. Depth is usually omitted.
  String applyForPersist(
    String text, {
    required RegexPlacement placement,
    bool isEdit = false,
    String? characterName,
    String? userName,
  }) {
    return _apply(
      text,
      placement: placement,
      isEdit: isEdit,
      characterName: characterName,
      userName: userName,
    );
  }

  String _apply(
    String text, {
    required RegexPlacement placement,
    int? depth,
    bool isMarkdown = false,
    bool isPrompt = false,
    bool isEdit = false,
    String? characterName,
    String? userName,
  }) {
    if (!_active || text.isEmpty || !_placementAllowed(placement)) {
      return text;
    }
    return _service.getRegexedString(
      text,
      placement,
      _scripts,
      characterName: characterName ?? this.characterName,
      userName: userName ?? this.userName,
      isMarkdown: isMarkdown,
      isPrompt: isPrompt,
      isEdit: isEdit,
      depth: depth,
    );
  }
}
