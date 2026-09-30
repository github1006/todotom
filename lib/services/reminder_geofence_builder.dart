import 'package:geofence_service/geofence_service.dart';

import '../models/place.dart';
import '../models/todo_item.dart';

class ReminderGeofenceBuilder {
  static Set<String> pendingPlaceIds(List<TodoItem> todos) {
    return todos
        .where((todo) => !todo.done && todo.placeId != null)
        .map((todo) => todo.placeId!)
        .toSet();
  }

  static bool hasPendingLocationTodos(List<TodoItem> todos) {
    return pendingPlaceIds(todos).isNotEmpty;
  }

  static List<Geofence> build({
    required List<Place> places,
    required List<TodoItem> todos,
  }) {
    final placeIdsWithPending = pendingPlaceIds(todos);
    if (placeIdsWithPending.isEmpty) {
      return const [];
    }

    return places
        .where((place) => placeIdsWithPending.contains(place.id))
        .map(
          (place) => Geofence(
            id: place.id,
            latitude: place.latitude,
            longitude: place.longitude,
            radius: [
              GeofenceRadius(
                id: '${place.id}_radius',
                length: place.radiusMeters.clamp(100, 500),
              ),
            ],
          ),
        )
        .toList();
  }
}
