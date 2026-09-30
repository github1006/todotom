class TripDestination {
  TripDestination({
    required this.id,
    required this.name,
    this.notes,
    this.placeId,
  });

  final String id;
  final String name;
  final String? notes;
  final String? placeId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (notes != null) 'notes': notes,
        if (placeId != null) 'placeId': placeId,
      };

  factory TripDestination.fromJson(Map<String, dynamic> json) {
    return TripDestination(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      placeId: json['placeId'] as String?,
    );
  }

  TripDestination copyWith({
    String? name,
    String? notes,
    String? placeId,
    bool clearNotes = false,
    bool clearPlace = false,
  }) {
    return TripDestination(
      id: id,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      placeId: clearPlace ? null : (placeId ?? this.placeId),
    );
  }
}
