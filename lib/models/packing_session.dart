import 'trip_context.dart';

class PackingSessionItem {
  PackingSessionItem({
    required this.id,
    required this.sessionId,
    required this.title,
    this.done = false,
    this.sortOrder = 0,
  });

  final String id;
  final String sessionId;
  final String title;
  bool done;
  final int sortOrder;

  PackingSessionItem copyWith({bool? done}) {
    return PackingSessionItem(
      id: id,
      sessionId: sessionId,
      title: title,
      done: done ?? this.done,
      sortOrder: sortOrder,
    );
  }
}

class PackingSession {
  PackingSession({
    required this.id,
    this.destinationId,
    required this.tripContexts,
    required this.createdAt,
    required this.travelDate,
  });

  final String id;
  final String? destinationId;
  final List<TripContext> tripContexts;
  final DateTime createdAt;
  final DateTime travelDate;
}
