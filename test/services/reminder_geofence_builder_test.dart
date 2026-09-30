import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/place.dart';
import 'package:todotom/models/todo_item.dart';
import 'package:todotom/services/reminder_geofence_builder.dart';

void main() {
  group('ReminderGeofenceBuilder', () {
    test('ignora tareas completadas o sin lugar', () {
      final todos = [
        TodoItem(id: '1', title: 'Hecha', done: true, placeId: 'home'),
        TodoItem(id: '2', title: 'Sin lugar'),
        TodoItem(id: '3', title: 'Pendiente', placeId: 'shop'),
      ];

      expect(
        ReminderGeofenceBuilder.pendingPlaceIds(todos),
        {'shop'},
      );
    });

    test('construye geofences solo para lugares con tareas pendientes', () {
      final places = [
        Place(
          id: 'home',
          name: 'Casa',
          latitude: 10,
          longitude: 20,
          radiusMeters: 80,
        ),
        Place(
          id: 'shop',
          name: 'Tienda',
          latitude: 11,
          longitude: 21,
          radiusMeters: 600,
        ),
      ];
      final todos = [
        TodoItem(id: '1', title: 'Comprar', placeId: 'shop'),
      ];

      final geofences = ReminderGeofenceBuilder.build(
        places: places,
        todos: todos,
      );

      expect(geofences, hasLength(1));
      expect(geofences.first.id, 'shop');
      expect(geofences.first.radius.single.length, 500);
    });
  });
}
