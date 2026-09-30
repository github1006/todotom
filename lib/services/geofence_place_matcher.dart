import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

class GeofencePlaceMatcher {
  GeofencePlaceMatcher._();

  static double effectiveRadiusMeters(Place place) {
    return place.radiusMeters.clamp(100, 500);
  }

  static bool contains({
    required Place place,
    required double latitude,
    required double longitude,
  }) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      place.latitude,
      place.longitude,
    );
    return distance <= effectiveRadiusMeters(place);
  }
}
