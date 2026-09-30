import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/place.dart';
import 'package:todotom/repositories/sqlite/sqlite_place_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late SqlitePlaceRepository repository;

  setUp(() async {
    final database = await createTestDatabase();
    repository = SqlitePlaceRepository(database);
  });

  test('upsert y getAll persisten lugares', () async {
    final place = Place(
      id: 'p1',
      name: 'Feria x parada 8',
      latitude: 40.41,
      longitude: -3.70,
      radiusMeters: 250,
    );

    await repository.upsert(place);
    final places = await repository.getAll();

    expect(places, hasLength(1));
    expect(places.first.name, 'Feria x parada 8');
    expect(places.first.radiusMeters, 250);
  });

  test('delete elimina un lugar', () async {
    await repository.upsert(
      Place(id: 'p1', name: 'Super', latitude: 1, longitude: 2),
    );

    await repository.delete('p1');
    final places = await repository.getAll();

    expect(places, isEmpty);
  });

  test('replaceAll sincroniza la lista completa', () async {
    await repository.upsert(
      Place(id: 'old', name: 'Viejo', latitude: 1, longitude: 2),
    );

    await repository.replaceAll([
      Place(id: 'new', name: 'Nuevo', latitude: 3, longitude: 4),
    ]);

    final places = await repository.getAll();
    expect(places, hasLength(1));
    expect(places.first.id, 'new');
  });
}
