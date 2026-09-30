import '../models/place.dart';

abstract class PlaceRepository {
  Future<List<Place>> getAll();

  Future<Place?> findById(String id);

  Future<void> upsert(Place place);

  Future<void> upsertAll(List<Place> places);

  Future<void> replaceAll(List<Place> places);

  Future<void> delete(String id);
}
