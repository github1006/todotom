import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/place.dart';
import 'package:todotom/services/geofence_place_matcher.dart';

void main() {
  final place = Place(
    id: 'casa',
    name: 'Casa',
    latitude: 40.4168,
    longitude: -3.7038,
    radiusMeters: 250,
  );

  test('detecta posición dentro del radio', () {
    expect(
      GeofencePlaceMatcher.contains(
        place: place,
        latitude: 40.4175,
        longitude: -3.7038,
      ),
      isTrue,
    );
  });

  test('detecta posición fuera del radio', () {
    expect(
      GeofencePlaceMatcher.contains(
        place: place,
        latitude: 40.4300,
        longitude: -3.7038,
      ),
      isFalse,
    );
  });
}
