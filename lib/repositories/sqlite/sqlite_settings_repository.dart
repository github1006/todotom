import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../models/reminder_sound.dart';
import '../../models/trip_context.dart';
import '../settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database);

  final AppDatabase _database;

  static const remindersEnabledKey = 'reminders_enabled';
  static const reminderSoundUriKey = 'reminder_sound_uri';
  static const reminderSoundTitleKey = 'reminder_sound_title';
  static const legacyMigratedKey = 'legacy_prefs_migrated';
  static const lastPackingDestinationIdKey = 'packing_last_destination_id';
  static const lastTripDestinationIdKey = 'packing_last_trip_destination_id';
  static const lastPackingTripContextsKey = 'packing_last_trip_contexts';

  // Claves antiguas (migración)
  static const legacyReminderSoundIdKey = 'reminder_sound_id';
  static const legacyCustomSoundNameKey = 'custom_reminder_sound_name';

  Future<Database> get _db => _database.open();

  @override
  Future<bool> areRemindersEnabled() async {
    final value = await _read(remindersEnabledKey);
    return value != 'false';
  }

  @override
  Future<void> setRemindersEnabled(bool enabled) async {
    await _write(remindersEnabledKey, enabled.toString());
  }

  @override
  Future<ReminderSoundConfig> getReminderSound() async {
    final uri = await _read(reminderSoundUriKey);
    final title = await _read(reminderSoundTitleKey);
    if (uri != null && uri.isNotEmpty) {
      return ReminderSoundConfig(uri: uri, title: title);
    }
    return const ReminderSoundConfig();
  }

  @override
  Future<void> setReminderSound(ReminderSoundConfig sound) async {
    if (sound.uri == null || sound.uri!.isEmpty) {
      await clearReminderSound();
      return;
    }
    await _write(reminderSoundUriKey, sound.uri!);
    await _write(reminderSoundTitleKey, sound.title ?? 'Tono del teléfono');
    await _deleteLegacySoundKeys();
  }

  @override
  Future<void> clearReminderSound() async {
    final db = await _db;
    await db.delete(
      'settings',
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: [
        reminderSoundUriKey,
        reminderSoundTitleKey,
        legacyReminderSoundIdKey,
        legacyCustomSoundNameKey,
      ],
    );
  }

  Future<void> _deleteLegacySoundKeys() async {
    final db = await _db;
    await db.delete(
      'settings',
      where: 'key IN (?, ?)',
      whereArgs: [legacyReminderSoundIdKey, legacyCustomSoundNameKey],
    );
  }

  @override
  Future<bool> wasLegacyDataMigrated() async {
    final value = await _read(legacyMigratedKey);
    return value == 'true';
  }

  @override
  Future<void> setLegacyDataMigrated(bool migrated) async {
    await _write(legacyMigratedKey, migrated.toString());
  }

  @override
  Future<String?> getLastPackingDestinationId() async {
    final value = await _read(lastPackingDestinationIdKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> setLastPackingDestinationId(String? destinationId) async {
    if (destinationId == null || destinationId.isEmpty) {
      final db = await _db;
      await db.delete('settings', where: 'key = ?', whereArgs: [lastPackingDestinationIdKey]);
      return;
    }
    await _write(lastPackingDestinationIdKey, destinationId);
  }

  @override
  Future<String?> getLastTripDestinationId() async {
    final value = await _read(lastTripDestinationIdKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> setLastTripDestinationId(String destinationId) async {
    if (destinationId.isEmpty) return;
    await _write(lastTripDestinationIdKey, destinationId);
  }

  @override
  Future<Set<TripContext>> getLastPackingTripContexts() async {
    final value = await _read(lastPackingTripContextsKey);
    if (value == null || value.isEmpty) {
      return {TripContext.cityToField};
    }
    final keys = (jsonDecode(value) as List).cast<String>();
    final contexts = TripContextStorage.fromKeys(keys).toSet();
    if (contexts.isEmpty) {
      return {TripContext.cityToField};
    }
    return contexts;
  }

  @override
  Future<void> setLastPackingTripContexts(Set<TripContext> contexts) async {
    final filtered = contexts.where((c) => c != TripContext.everyTrip).toSet();
    if (filtered.isEmpty) {
      final db = await _db;
      await db.delete('settings', where: 'key = ?', whereArgs: [lastPackingTripContextsKey]);
      return;
    }
    await _write(
      lastPackingTripContextsKey,
      jsonEncode(TripContextStorage.toKeys(filtered)),
    );
  }

  Future<String?> _read(String key) async {
    final db = await _db;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _write(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
