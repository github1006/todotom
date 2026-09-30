import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../repositories/place_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/sqlite/sqlite_place_repository.dart';
import '../repositories/sqlite/sqlite_settings_repository.dart';
import '../repositories/sqlite/sqlite_todo_repository.dart';
import '../repositories/todo_repository.dart';
import '../services/legacy_data_migrator.dart';
import '../services/reminder_service.dart';

class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.todoRepository,
    required this.placeRepository,
    required this.settingsRepository,
    required this.reminderService,
  });

  final AppDatabase database;
  final TodoRepository todoRepository;
  final PlaceRepository placeRepository;
  final SettingsRepository settingsRepository;
  final ReminderService reminderService;

  static AppDependencies? _instance;

  static AppDependencies get instance {
    final dependencies = _instance;
    if (dependencies == null) {
      throw StateError('AppDependencies no inicializado. Llama a initialize() primero.');
    }
    return dependencies;
  }

  static Future<AppDependencies> initialize() {
    return _create(AppDatabase());
  }

  @visibleForTesting
  static Future<AppDependencies> initializeWithDatabase(AppDatabase database) {
    return _create(
      database,
      skipLegacyMigration: true,
      skipReminderInit: true,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  static Future<AppDependencies> _create(
    AppDatabase database, {
    bool skipLegacyMigration = false,
    bool skipReminderInit = false,
  }) async {
    if (_instance != null) {
      return _instance!;
    }

    final todoRepository = SqliteTodoRepository(database);
    final placeRepository = SqlitePlaceRepository(database);
    final settingsRepository = SqliteSettingsRepository(database);

    if (!skipLegacyMigration) {
      await LegacyDataMigrator(
        todoRepository: todoRepository,
        placeRepository: placeRepository,
        settingsRepository: settingsRepository,
      ).migrateIfNeeded();
    }

    final reminderService = ReminderService();
    if (!skipReminderInit) {
      await reminderService.init();
    }

    _instance = AppDependencies._(
      database: database,
      todoRepository: todoRepository,
      placeRepository: placeRepository,
      settingsRepository: settingsRepository,
      reminderService: reminderService,
    );

    return _instance!;
  }
}
