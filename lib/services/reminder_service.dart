import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/place.dart';
import '../models/todo_item.dart';
import 'notification_service.dart';
import 'reminder_geofence_builder.dart';
import 'reminder_permission_result.dart';
import 'reminder_task_handler.dart';

class ReminderService {
  ReminderService();

  static const _foregroundServiceId = 512;

  Future<void> init() async {
    FlutterForegroundTask.initCommunicationPort();
    await NotificationService.init();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'reminder_monitoring',
        channelName: 'Monitoreo de lugares',
        channelDescription: 'Mantiene activos los recordatorios por ubicación',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> hasBackgroundLocation() async {
    final status = await FlLocation.checkLocationPermission();
    return status == LocationPermission.always;
  }

  Future<ReminderPermissionResult> requestPermissions() async {
    final notification = await Permission.notification.request();
    if (!notification.isGranted) {
      return ReminderPermissionResult.denied(
        'Activa las notificaciones para recibir avisos',
      );
    }

    if (!await FlLocation.isLocationServicesEnabled) {
      return ReminderPermissionResult.denied(
        'Activa el GPS del teléfono',
      );
    }

    var locationPermission = await FlLocation.checkLocationPermission();
    if (locationPermission == LocationPermission.deniedForever) {
      return ReminderPermissionResult.needsBackground();
    }

    if (locationPermission == LocationPermission.denied) {
      locationPermission = await FlLocation.requestLocationPermission();
    }

    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      return ReminderPermissionResult.denied(
        'Activa la ubicación para recordatorios por lugar',
      );
    }

    if (locationPermission == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
      locationPermission = await FlLocation.checkLocationPermission();
    }

    if (locationPermission != LocationPermission.always) {
      return ReminderPermissionResult.needsBackground();
    }

    if (Platform.isAndroid) {
      final fgNotificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (fgNotificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    return ReminderPermissionResult.ready();
  }

  Future<ReminderPermissionResult> sync({
    required List<Place> places,
    required List<TodoItem> todos,
    required bool remindersEnabled,
  }) async {
    try {
      if (!remindersEnabled || !ReminderGeofenceBuilder.hasPendingLocationTodos(todos)) {
        await _stopForegroundMonitoring();
        return ReminderPermissionResult.notNeeded();
      }

      final permissionResult = await requestPermissions();
      if (!permissionResult.isReady) {
        return permissionResult;
      }

      final geofences = ReminderGeofenceBuilder.build(
        places: places,
        todos: todos,
      );

      if (geofences.isEmpty) {
        await _stopForegroundMonitoring();
        return ReminderPermissionResult.denied(
          'La tarea tiene un lugar que ya no existe. Vuelve a asignarlo.',
        );
      }

      final startResult = await _startForegroundMonitoring(
        placeCount: ReminderGeofenceBuilder.pendingPlaceIds(todos).length,
      );

      if (startResult is ServiceRequestFailure) {
        return _mapForegroundError(startResult.error);
      }

      return ReminderPermissionResult.ready();
    } catch (error) {
      return _mapError(error);
    }
  }

  Future<ServiceRequestResult> _startForegroundMonitoring({
    required int placeCount,
  }) async {
    final notificationText =
        'Monitoreando $placeCount lugar(es) con tareas pendientes';

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(reminderTaskSyncCommand);
      return FlutterForegroundTask.updateService(notificationText: notificationText);
    }

    return FlutterForegroundTask.startService(
      serviceId: _foregroundServiceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'TodoTom — recordatorios activos',
      notificationText: notificationText,
      callback: startReminderTask,
    );
  }

  Future<void> _stopForegroundMonitoring() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  ReminderPermissionResult _mapForegroundError(Object error) {
    if (kDebugMode) {
      debugPrint('Reminder foreground service error: $error');
    }

    return ReminderPermissionResult.denied(
      'No se pudieron activar los recordatorios en segundo plano',
    );
  }

  ReminderPermissionResult _mapError(dynamic error) {
    final code = getErrorCodesFromError(error);

    switch (code) {
      case ErrorCodes.LOCATION_SERVICES_DISABLED:
        return ReminderPermissionResult.denied('Activa el GPS del teléfono');
      case ErrorCodes.LOCATION_PERMISSION_DENIED:
      case ErrorCodes.LOCATION_PERMISSION_PERMANENTLY_DENIED:
        return ReminderPermissionResult.needsBackground();
      case ErrorCodes.ACTIVITY_RECOGNITION_PERMISSION_DENIED:
      case ErrorCodes.ACTIVITY_RECOGNITION_PERMISSION_PERMANENTLY_DENIED:
        return ReminderPermissionResult.denied(
          'Activa el permiso de actividad física en ajustes',
          openSettings: true,
        );
      case ErrorCodes.ALREADY_STARTED:
        return ReminderPermissionResult.ready();
      default:
        return ReminderPermissionResult.denied(
          'No se pudieron activar los recordatorios por ubicación',
        );
    }
  }
}
