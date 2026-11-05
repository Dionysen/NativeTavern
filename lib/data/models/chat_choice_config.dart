import 'dart:convert';

/// Per-option guidance assembled into the choice-generation prompt.
class ChatChoiceSlotConfig {
  final String tendency;

  const ChatChoiceSlotConfig({this.tendency = ''});

  ChatChoiceSlotConfig copyWith({String? tendency}) {
    return ChatChoiceSlotConfig(tendency: tendency ?? this.tendency);
  }

  Map<String, dynamic> toJson() => {'tendency': tendency};

  factory ChatChoiceSlotConfig.fromJson(Map<String, dynamic> json) {
    return ChatChoiceSlotConfig(tendency: json['tendency'] as String? ?? '');
  }
}

/// Global settings for AI-generated reply choices after assistant turns.
class ChatChoiceConfig {
  static const int minChoiceCount = 2;
  static const int maxChoiceCount = 8;
  static const int defaultChoiceCount = 4;
  static const int defaultMaxChars = 80;

  static const String defaultPromptTemplate = '''
Based on the conversation so far, suggest {{count}} distinct reply options the user could send next.
Each option must be at most {{max_chars}} characters (count characters, not bytes).
Write options in the same language as the recent messages.
Return ONLY valid JSON in this exact shape: {"choices":["option1","option2"]}
Do not wrap in markdown or add commentary.

Per-option guidance:
{{option_lines}}
''';

  final bool enabled;
  final int choiceCount;
  final int maxCharsPerChoice;
  final String promptTemplate;
  final List<ChatChoiceSlotConfig> slots;

  const ChatChoiceConfig({
    this.enabled = false,
    this.choiceCount = defaultChoiceCount,
    this.maxCharsPerChoice = defaultMaxChars,
    this.promptTemplate = defaultPromptTemplate,
    this.slots = const [],
  });

  static ChatChoiceConfig get defaultConfig => ChatChoiceConfig(
        slots: List.generate(
          defaultChoiceCount,
          (_) => const ChatChoiceSlotConfig(),
        ),
      );

  List<ChatChoiceSlotConfig> normalizedSlots() {
    final count = choiceCount.clamp(minChoiceCount, maxChoiceCount);
    final list = List<ChatChoiceSlotConfig>.from(slots);
    while (list.length < count) {
      list.add(const ChatChoiceSlotConfig());
    }
    if (list.length > count) {
      return list.sublist(0, count);
    }
    return list;
  }

  ChatChoiceConfig copyWith({
    bool? enabled,
    int? choiceCount,
    int? maxCharsPerChoice,
    String? promptTemplate,
    List<ChatChoiceSlotConfig>? slots,
  }) {
    return ChatChoiceConfig(
      enabled: enabled ?? this.enabled,
      choiceCount: choiceCount ?? this.choiceCount,
      maxCharsPerChoice: maxCharsPerChoice ?? this.maxCharsPerChoice,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      slots: slots ?? this.slots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'choiceCount': choiceCount,
      'maxCharsPerChoice': maxCharsPerChoice,
      'promptTemplate': promptTemplate,
      'slots': normalizedSlots().map((s) => s.toJson()).toList(),
    };
  }

  factory ChatChoiceConfig.fromJson(Map<String, dynamic> json) {
    final count = (json['choiceCount'] as num?)?.toInt() ?? defaultChoiceCount;
    final rawSlots = json['slots'] as List<dynamic>?;
    final slots = rawSlots == null
        ? <ChatChoiceSlotConfig>[]
        : rawSlots
            .map(
              (e) => ChatChoiceSlotConfig.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
    final config = ChatChoiceConfig(
      enabled: json['enabled'] as bool? ?? false,
      choiceCount: count,
      maxCharsPerChoice:
          (json['maxCharsPerChoice'] as num?)?.toInt() ?? defaultMaxChars,
      promptTemplate:
          json['promptTemplate'] as String? ?? defaultPromptTemplate,
      slots: slots,
    );
    return config.copyWith(slots: config.normalizedSlots());
  }

  String toJsonString() => jsonEncode(toJson());

  factory ChatChoiceConfig.fromJsonString(String jsonString) {
    return ChatChoiceConfig.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
