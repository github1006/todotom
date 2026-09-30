import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todotom/models/place.dart';
import 'package:todotom/models/todo_item.dart';
import 'package:todotom/repositories/sqlite/sqlite_place_repository.dart';
import 'package:todotom/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:todotom/repositories/sqlite/sqlite_todo_repository.dart';
import 'package:todotom/services/legacy_data_migrator.dart';

import '../helpers/test_database.dart';

void main() {
  test('migra datos de SharedPreferences a SQLite una sola vez', () async {
    SharedPreferences.setMockInitialValues({
      'todos': jsonEncode([
        {'id': '1', 'title': 'Comprar leche', 'done': false},
      ]),
      'places': jsonEncode([
        {
          'id': 'p1',
          'name': 'Super',
          'latitude': 40.0,
          'longitude': -3.0,
          'radiusMeters': 200,
        },
      ]),
      'reminders_enabled': false,
    });

    final database = await createTestDatabase();
    final todoRepository = SqliteTodoRepository(database);
    final placeRepository = SqlitePlaceRepository(database);
    final settingsRepository = SqliteSettingsRepository(database);

    final migrator = LegacyDataMigrator(
      todoRepository: todoRepository,
      placeRepository: placeRepository,
      settingsRepository: settingsRepository,
    );

    await migrator.migrateIfNeeded();
    await migrator.migrateIfNeeded();

    final todos = await todoRepository.getAll();
    final places = await placeRepository.getAll();

    expect(todos, hasLength(1));
    expect(todos.first, isA<TodoItem>());
    expect(todos.first.title, 'Comprar leche');
    expect(places, hasLength(1));
    expect(places.first, isA<Place>());
    expect(places.first.name, 'Super');
    expect(await settingsRepository.areRemindersEnabled(), isFalse);
    expect(await settingsRepository.wasLegacyDataMigrated(), isTrue);
  });
}
