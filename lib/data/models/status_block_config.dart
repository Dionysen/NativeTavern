import 'dart:convert';

/// One configurable status field shown in the built-in status panel.
class StatusFieldSlot {
  final String id;
  final String label;
  final bool locked;

  const StatusFieldSlot({
    required this.id,
    required this.label,
    this.locked = false,
  });

  StatusFieldSlot copyWith({
    String? id,
    String? label,
    bool? locked,
  }) {
    return StatusFieldSlot(
      id: id ?? this.id,
      label: label ?? this.label,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'locked': locked,
      };

  factory StatusFieldSlot.fromJson(Map<String, dynamic> json) {
    return StatusFieldSlot(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      locked: json['locked'] as bool? ?? false,
    );
  }
}

/// Per-character status snapshot stored on a message or in session state.
class StatusCharacterSnapshot {
  final String name;
  final Map<String, String> fields;

  const StatusCharacterSnapshot({
    required this.name,
    this.fields = const {},
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'fields': fields,
      };

  factory StatusCharacterSnapshot.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final fields = <String, String>{};
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        fields[key] = '${entry.value}'.trim();
      }
    }
    return StatusCharacterSnapshot(
      name: (json['name'] as String?)?.trim() ?? '',
      fields: fields,
    );
  }
}

/// Structured status block (builtin generation or parsed from card HTML).
class StatusBlockSnapshot {
  static const metadataKey = 'statusBlock';

  final int version;
  final String source;
  final List<StatusCharacterSnapshot> characters;

  const StatusBlockSnapshot({
    this.version = 1,
    this.source = 'builtin',
    this.characters = const [],
  });

  bool get isEmpty => characters.isEmpty;

  Map<String, dynamic> toJson() => {
        'version': version,
        'source': source,
        'characters': characters.map((c) => c.toJson()).toList(),
      };

  factory StatusBlockSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['characters'];
    final characters = <StatusCharacterSnapshot>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          characters.add(StatusCharacterSnapshot.fromJson(item));
        } else if (item is Map) {
          characters.add(
            StatusCharacterSnapshot.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    return StatusBlockSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      source: json['source'] as String? ?? 'builtin',
      characters: characters,
    );
  }

  static StatusBlockSnapshot? fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata[metadataKey];
    if (raw is! Map) return null;
    final snapshot = StatusBlockSnapshot.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (snapshot.isEmpty) return null;
    return snapshot;
  }

  String toCompactText() {
    final buffer = StringBuffer();
    for (final character in characters) {
      if (character.name.isEmpty) continue;
      buffer.writeln(character.name);
      for (final entry in character.fields.entries) {
        if (entry.value.trim().isEmpty) continue;
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    return buffer.toString().trim();
  }
}

/// Global settings for AI-generated character status after assistant turns.
class StatusBlockConfig {
  static const int maxFields = 16;

  static const List<StatusFieldSlot> defaultFields = [
    StatusFieldSlot(id: 'name', label: '名字', locked: true),
    StatusFieldSlot(id: 'outfit', label: '穿搭'),
    StatusFieldSlot(id: 'action', label: '行动'),
    StatusFieldSlot(id: 'thoughts', label: '内心'),
    StatusFieldSlot(id: 'arousal', label: '性唤起程度'),
  ];

  static const String defaultPromptTemplate = '''
Based on the conversation so far, update the status of each character listed below.
Use ONLY these field labels (exact spelling):
{{field_lines}}

Characters to cover:
{{character_lines}}

Previous status (may be empty):
{{previous_status}}

Write values in the same language as the recent messages.
Keep each value short and concrete. Do not invent events that have not happened.
Return ONLY valid JSON in this exact shape:
{"characters":[{"name":"Display Name","fields":{"穿搭":"...","行动":"...","内心":"...","性唤起程度":"..."}}]}
Every character must include a "name" matching the list above.
Do not wrap in markdown or add commentary.
''';

  final bool enabled;
  final bool injectIntoContext;
  final bool autoDisableWhenCardHasStatus;
  final String promptTemplate;
  final List<StatusFieldSlot> fields;

  const StatusBlockConfig({
    this.enabled = false,
    this.injectIntoContext = true,
    this.autoDisableWhenCardHasStatus = true,
    this.promptTemplate = defaultPromptTemplate,
    this.fields = defaultFields,
  });

  static StatusBlockConfig get defaultConfig => const StatusBlockConfig();

  List<StatusFieldSlot> normalizedFields() {
    final list = <StatusFieldSlot>[];
    var hasLockedName = false;
    for (final field in fields) {
      final id = field.id.trim();
      final label = field.label.trim();
      if (id.isEmpty || label.isEmpty) continue;
      final locked = field.locked || id == 'name';
      if (locked) {
        if (hasLockedName) continue;
        hasLockedName = true;
        list.insert(
          0,
          StatusFieldSlot(id: 'name', label: label.isEmpty ? '名字' : label, locked: true),
        );
      } else {
        list.add(StatusFieldSlot(id: id, label: label));
      }
    }
    if (!hasLockedName) {
      list.insert(0, defaultFields.first);
    }
    if (list.length > maxFields) {
      return list.sublist(0, maxFields);
    }
    return list;
  }

  StatusBlockConfig copyWith({
    bool? enabled,
    bool? injectIntoContext,
    bool? autoDisableWhenCardHasStatus,
    String? promptTemplate,
    List<StatusFieldSlot>? fields,
  }) {
    return StatusBlockConfig(
      enabled: enabled ?? this.enabled,
      injectIntoContext: injectIntoContext ?? this.injectIntoContext,
      autoDisableWhenCardHasStatus:
          autoDisableWhenCardHasStatus ?? this.autoDisableWhenCardHasStatus,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      fields: fields ?? this.fields,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'injectIntoContext': injectIntoContext,
        'autoDisableWhenCardHasStatus': autoDisableWhenCardHasStatus,
        'promptTemplate': promptTemplate,
        'fields': normalizedFields().map((f) => f.toJson()).toList(),
      };

  factory StatusBlockConfig.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as List<dynamic>?;
    final fields = rawFields == null
        ? defaultFields
        : rawFields
            .whereType<Map>()
            .map((e) => StatusFieldSlot.fromJson(Map<String, dynamic>.from(e)))
            .toList();
    final config = StatusBlockConfig(
      enabled: json['enabled'] as bool? ?? false,
      injectIntoContext: json['injectIntoContext'] as bool? ?? true,
      autoDisableWhenCardHasStatus:
          json['autoDisableWhenCardHasStatus'] as bool? ?? true,
      promptTemplate:
          json['promptTemplate'] as String? ?? defaultPromptTemplate,
      fields: fields,
    );
    return config.copyWith(fields: config.normalizedFields());
  }

  String toJsonString() => jsonEncode(toJson());

  factory StatusBlockConfig.fromJsonString(String jsonString) {
    return StatusBlockConfig.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
