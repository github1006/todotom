import 'dart:io';

import 'package:flutter/services.dart';

class PickedReminderSound {
  const PickedReminderSound({required this.uri, required this.title});

  final String uri;
  final String title;
}

class SystemReminderSoundService {
  SystemReminderSoundService._();

  static const _channel = MethodChannel('com.example.todotom/reminder_sound');

  static Future<PickedReminderSound?> pickSound({String? existingUri}) async {
    if (!Platform.isAndroid) return null;

    final result = await _channel.invokeMethod<Object?>(
      'pickSound',
      {'existingUri': existingUri},
    );

    if (result is! Map) return null;
    final uri = result['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;

    final title = result['title'] as String?;
    return PickedReminderSound(
      uri: uri,
      title: (title != null && title.isNotEmpty) ? title : 'Tono del teléfono',
    );
  }
}
