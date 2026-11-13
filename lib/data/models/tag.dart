/// Tag model for categorizing characters
class Tag {
  final String id;
  final String name;
  final String? color; // Hex color string like "#FF5733"
  final String? icon; // Icon name or emoji
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.createdAt,
  });

  Tag copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tag(id: $id, name: $name, color: $color)';
}