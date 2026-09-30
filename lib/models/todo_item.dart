class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    this.done = false,
    this.placeId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  bool done;
  String? placeId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        if (placeId != null) 'placeId': placeId,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String,
      done: json['done'] as bool? ?? false,
      placeId: json['placeId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
    );
  }

  TodoItem copyWith({
    String? title,
    bool? done,
    String? placeId,
    bool clearPlace = false,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
      placeId: clearPlace ? null : (placeId ?? this.placeId),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
