import '../models/reminder_sound.dart';

abstract class SettingsRepository {
  Future<bool> areRemindersEnabled();

  Future<void> setRemindersEnabled(bool enabled);

  Future<ReminderSoundConfig> getReminderSound();

  Future<void> setReminderSound(ReminderSoundConfig sound);

  Future<void> clearReminderSound();

  Future<bool> wasLegacyDataMigrated();

  Future<void> setLegacyDataMigrated(bool migrated);
}
