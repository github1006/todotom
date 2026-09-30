import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/reminder_sound.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelVersion = 'v5';
  static const _defaultChannelId = 'todotom_reminder_default_$_channelVersion';
  static const _channelName = 'Recordatorios por lugar';
  static const _channelDescription = 'Avisos al llegar a un lugar marcado en el mapa';

  static const _legacyChannelIds = [
    'place_reminders',
    'todotom_reminder_default_v4',
    'todotom_reminder_bell_v4',
    'todotom_reminder_chime_v4',
    'todotom_reminder_alert_v4',
    'todotom_reminder_pop_v4',
    'todotom_reminder_urgent_v4',
    'todotom_reminder_digital_v4',
    'todotom_reminder_custom_v4',
  ];

  static Future<void> init() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(settings);
      await syncChannels(const ReminderSoundConfig());
      _initialized = true;
    } on Object {
      // Sin canal de plataforma (p. ej. tests en VM).
    }
  }

  static String _channelIdFor(ReminderSoundConfig sound) {
    final uri = sound.uri;
    if (uri == null || uri.isEmpty) return _defaultChannelId;
    return 'todotom_reminder_uri_${uri.hashCode}_$_channelVersion';
  }

  static Future<void> syncChannels(ReminderSoundConfig sound) async {
    if (!_initialized) return;

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    for (final channelId in _legacyChannelIds) {
      await androidPlugin.deleteNotificationChannel(channelId);
    }

    await androidPlugin.deleteNotificationChannel(_defaultChannelId);
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _defaultChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      ),
    );

    if (!sound.usesSystemPicker) return;

    final channelId = _channelIdFor(sound);
    await androidPlugin.deleteNotificationChannel(channelId);
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        _channelName,
        description: '${sound.displayLabel} · $_channelDescription',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: UriAndroidNotificationSound(sound.uri!),
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      ),
    );
  }

  static NotificationDetails _detailsFor(ReminderSoundConfig sound) {
    final AndroidNotificationSound? androidSound =
        sound.usesSystemPicker ? UriAndroidNotificationSound(sound.uri!) : null;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelIdFor(sound),
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        sound: androidSound,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  static Future<void> showPlaceReminder({
    required String placeName,
    required List<String> todoTitles,
    required ReminderSoundConfig sound,
  }) async {
    if (todoTitles.isEmpty) return;

    final body = todoTitles.length == 1
        ? todoTitles.first
        : '${todoTitles.take(3).join(', ')}${todoTitles.length > 3 ? '...' : ''}';

    await _plugin.show(
      placeName.hashCode,
      'En $placeName',
      body,
      _detailsFor(sound),
    );
  }

  static Future<void> showTestReminder({required ReminderSoundConfig sound}) async {
    await _plugin.show(
      999001,
      'Prueba: ${sound.displayLabel}',
      sound.usesSystemPicker
          ? 'Así sonará tu aviso al llegar a un lugar'
          : 'Tono predeterminado de notificaciones del teléfono',
      _detailsFor(sound),
    );
  }
}
