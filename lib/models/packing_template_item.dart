import 'dart:convert';

import 'trip_context.dart';

class PackingTemplateItem {
  PackingTemplateItem({
    required this.id,
    required this.title,
    this.destinationId,
    List<TripContext>? tripContexts,
    this.sortOrder = 0,
  }) : tripContexts = tripContexts ?? const [];

  final String id;
  final String title;
  final String? destinationId;
  final List<TripContext> tripContexts;
  final int sortOrder;

  bool get isDestinationSpecific => destinationId != null && destinationId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (destinationId != null) 'destinationId': destinationId,
        'tripContexts': TripContextStorage.toKeys(tripContexts),
        'sortOrder': sortOrder,
      };

  factory PackingTemplateItem.fromJson(Map<String, dynamic> json) {
    final rawContexts = json['tripContexts'];
    List<String> keys;
    if (rawContexts is String) {
      keys = (jsonDecode(rawContexts) as List).cast<String>();
    } else if (rawContexts is List) {
      keys = rawContexts.cast<String>();
    } else {
      keys = const [];
    }

    return PackingTemplateItem(
      id: json['id'] as String,
      title: json['title'] as String,
      destinationId: json['destinationId'] as String?,
      tripContexts: TripContextStorage.fromKeys(keys),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  PackingTemplateItem copyWith({
    String? title,
    String? destinationId,
    List<TripContext>? tripContexts,
    int? sortOrder,
    bool clearDestination = false,
  }) {
    return PackingTemplateItem(
      id: id,
      title: title ?? this.title,
      destinationId: clearDestination ? null : (destinationId ?? this.destinationId),
      tripContexts: tripContexts ?? this.tripContexts,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
