class TagDefinition {
  const TagDefinition({
    required this.tagName,
    required this.isHidden,
    required this.sortOrder,
    required this.createdAt,
  });

  final String tagName;
  final bool isHidden;
  final int sortOrder;
  final String createdAt;

  factory TagDefinition.fromMap(Map<String, Object?> map) {
    return TagDefinition(
      tagName: (map['tag_name'] as String?) ?? '',
      isHidden: ((map['is_hidden'] as int?) ?? 0) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: (map['created_at'] as String?) ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'tag_name': tagName,
      'is_hidden': isHidden ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }
}
