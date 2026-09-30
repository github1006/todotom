import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';
import '../models/todo_item.dart';
import '../repositories/place_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/todo_repository.dart';

class LegacyDataMigrator {
  LegacyDataMigrator({
    required TodoRepository todoRepository,
    required PlaceRepository placeRepository,
    required SettingsRepository settingsRepository,
    SharedPreferences? sharedPreferences,
  })  : _todoRepository = todoRepository,
        _placeRepository = placeRepository,
        _settingsRepository = settingsRepository,
        _sharedPreferences = sharedPreferences;

  static const todosKey = 'todos';
  static const placesKey = 'places';
  static const remindersEnabledKey = 'reminders_enabled';

  final TodoRepository _todoRepository;
  final PlaceRepository _placeRepository;
  final SettingsRepository _settingsRepository;
  final SharedPreferences? _sharedPreferences;

  Future<void> migrateIfNeeded() async {
    if (await _settingsRepository.wasLegacyDataMigrated()) {
      return;
    }

    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final todos = _readTodos(prefs);
    final places = _readPlaces(prefs);
    final remindersEnabled = prefs.getBool(remindersEnabledKey);

    if (todos.isNotEmpty) {
      await _todoRepository.replaceAll(todos);
    }
    if (places.isNotEmpty) {
      await _placeRepository.replaceAll(places);
    }
    if (remindersEnabled != null) {
      await _settingsRepository.setRemindersEnabled(remindersEnabled);
    }

    await _settingsRepository.setLegacyDataMigrated(true);
  }

  List<TodoItem> _readTodos(SharedPreferences prefs) {
    final raw = prefs.getString(todosKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) => TodoItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  List<Place> _readPlaces(SharedPreferences prefs) {
    final raw = prefs.getString(placesKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) => Place.fromJson(item as Map<String, dynamic>)).toList();
  }
}
