import '../models/reminder_sound.dart';
import '../models/trip_context.dart';

abstract class SettingsRepository {
  Future<bool> areRemindersEnabled();

  Future<void> setRemindersEnabled(bool enabled);

  Future<ReminderSoundConfig> getReminderSound();

  Future<void> setReminderSound(ReminderSoundConfig sound);

  Future<void> clearReminderSound();

  Future<bool> wasLegacyDataMigrated();

  Future<void> setLegacyDataMigrated(bool migrated);

  Future<String?> getLastPackingDestinationId();

  Future<void> setLastPackingDestinationId(String? destinationId);

  /// Último destino usado al alistar la maleta (pestaña Viaje).
  Future<String?> getLastTripDestinationId();

  Future<void> setLastTripDestinationId(String destinationId);

  Future<Set<TripContext>> getLastPackingTripContexts();

  Future<void> setLastPackingTripContexts(Set<TripContext> contexts);
}
