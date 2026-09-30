import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../database/app_database.dart';
import '../models/place.dart';
import '../repositories/sqlite/sqlite_place_repository.dart';
import '../repositories/sqlite/sqlite_settings_repository.dart';
import '../repositories/sqlite/sqlite_todo_repository.dart';
import 'geofence_place_matcher.dart';
import 'notification_service.dart';
import 'reminder_geofence_builder.dart';

const reminderTaskSyncCommand = 'sync';

@pragma('vm:entry-point')
void startReminderTask() {
  FlutterForegroundTask.setTaskHandler(ReminderTaskHandler());
}

class ReminderTaskHandler extends TaskHandler {
  bool _geofenceListenerRegistered = false;
  final Set<String> _notifiedPlaceIds = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    await _startMonitoring();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _stopMonitoring();
  }

  @override
  void onReceiveData(Object data) {
    if (data == reminderTaskSyncCommand) {
      unawaited(_startMonitoring());
    }
  }

  Future<void> _startMonitoring() async {
    await _stopMonitoring();

    final database = AppDatabase();
    final settingsRepository = SqliteSettingsRepository(database);
    final todoRepository = SqliteTodoRepository(database);
    final placeRepository = SqlitePlaceRepository(database);

    if (!await settingsRepository.areRemindersEnabled()) {
      await FlutterForegroundTask.stopService();
      return;
    }

    final todos = await todoRepository.getAll();
    final places = await placeRepository.getAll();
    final geofences = ReminderGeofenceBuilder.build(
      places: places,
      todos: todos,
    );

    if (geofences.isEmpty) {
      await FlutterForegroundTask.stopService();
      return;
    }

    await NotificationService.init();

    GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: false,
      allowMockLocations: false,
      printDevLog: false,
    );

    if (!_geofenceListenerRegistered) {
      GeofenceService.instance.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceListenerRegistered = true;
    }

    await GeofenceService.instance.start(geofences);
    await _checkAlreadyInsidePlaces(places: places);

    final pendingCount = ReminderGeofenceBuilder.pendingPlaceIds(todos).length;
    await FlutterForegroundTask.updateService(
      notificationText: 'Monitoreando $pendingCount lugar(es) con tareas pendientes',
    );
  }

  Future<void> _stopMonitoring() async {
    if (GeofenceService.instance.isRunningService) {
      await GeofenceService.instance.stop();
    }
  }

  Future<void> _checkAlreadyInsidePlaces({required List<Place> places}) async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      for (final place in places) {
        if (_notifiedPlaceIds.contains(place.id)) continue;
        if (!GeofencePlaceMatcher.contains(
          place: place,
          latitude: position.latitude,
          longitude: position.longitude,
        )) {
          continue;
        }

        await _notifyForPlace(place.id);
      }
    } on Object {
      // Sin GPS momentáneo; el aviso llegará al entrar al área.
    }
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    if (geofenceStatus == GeofenceStatus.EXIT) {
      _notifiedPlaceIds.remove(geofence.id);
      return;
    }

    if (geofenceStatus != GeofenceStatus.ENTER) return;

    await _notifyForPlace(geofence.id);
  }

  Future<void> _notifyForPlace(String placeId) async {
    if (_notifiedPlaceIds.contains(placeId)) return;

    final database = AppDatabase();
    final settingsRepository = SqliteSettingsRepository(database);
    final placeRepository = SqlitePlaceRepository(database);
    final todoRepository = SqliteTodoRepository(database);

    final place = await placeRepository.findById(placeId);
    if (place == null) return;

    final todos = await todoRepository.findPendingByPlace(place.id);
    if (todos.isEmpty) return;

    final sound = await settingsRepository.getReminderSound();

    await NotificationService.showPlaceReminder(
      placeName: place.name,
      todoTitles: todos.map((todo) => todo.title).toList(),
      sound: sound,
    );

    _notifiedPlaceIds.add(placeId);
  }
}
