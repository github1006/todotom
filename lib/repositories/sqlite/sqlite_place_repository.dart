import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../models/place.dart';
import '../place_repository.dart';

class SqlitePlaceRepository implements PlaceRepository {
  SqlitePlaceRepository(this._database);

  final AppDatabase _database;

  Future<Database> get _db => _database.open();

  @override
  Future<List<Place>> getAll() async {
    final db = await _db;
    final rows = await db.query('places', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Place?> findById(String id) async {
    final db = await _db;
    final rows = await db.query('places', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> upsert(Place place) async {
    final db = await _db;
    await db.insert('places', _toRow(place), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> upsertAll(List<Place> places) async {
    final db = await _db;
    final batch = db.batch();
    for (final place in places) {
      batch.insert('places', _toRow(place), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> replaceAll(List<Place> places) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('places');
      for (final place in places) {
        await txn.insert('places', _toRow(place));
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('places', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toRow(Place place) {
    return {
      'id': place.id,
      'name': place.name,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'radius_meters': place.radiusMeters,
    };
  }

  Place _fromRow(Map<String, Object?> row) {
    return Place(
      id: row['id']! as String,
      name: row['name']! as String,
      latitude: (row['latitude']! as num).toDouble(),
      longitude: (row['longitude']! as num).toDouble(),
      radiusMeters: (row['radius_meters']! as num).toDouble(),
    );
  }
}
