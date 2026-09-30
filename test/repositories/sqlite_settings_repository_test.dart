import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/reminder_sound.dart';
import 'package:todotom/models/trip_context.dart';
import 'package:todotom/repositories/sqlite/sqlite_settings_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late SqliteSettingsRepository repository;

  setUp(() async {
    final database = await createTestDatabase();
    repository = SqliteSettingsRepository(database);
  });

  test('areRemindersEnabled es true por defecto', () async {
    expect(await repository.areRemindersEnabled(), isTrue);
  });

  test('setRemindersEnabled persiste el valor', () async {
    await repository.setRemindersEnabled(false);
    expect(await repository.areRemindersEnabled(), isFalse);
  });

  test('getReminderSound es predeterminado por defecto', () async {
    final sound = await repository.getReminderSound();
    expect(sound.usesSystemPicker, isFalse);
    expect(sound.displayLabel, 'Predeterminado del teléfono');
  });

  test('setReminderSound persiste uri y titulo', () async {
    await repository.setReminderSound(
      const ReminderSoundConfig(
        uri: 'content://media/internal/audio/media/42',
        title: 'Pixie Dust',
      ),
    );

    final sound = await repository.getReminderSound();
    expect(sound.uri, 'content://media/internal/audio/media/42');
    expect(sound.title, 'Pixie Dust');
    expect(sound.displayLabel, 'Pixie Dust');
  });

  test('clearReminderSound vuelve al predeterminado', () async {
    await repository.setReminderSound(
      const ReminderSoundConfig(uri: 'content://tone/1', title: 'Tono'),
    );
    await repository.clearReminderSound();

    final sound = await repository.getReminderSound();
    expect(sound.usesSystemPicker, isFalse);
  });

  test('setLastPackingTripContexts recuerda tipos de viaje', () async {
    await repository.setLastPackingTripContexts({
      TripContext.fieldDay,
      TripContext.cityToField,
    });
    final contexts = await repository.getLastPackingTripContexts();
    expect(contexts, contains(TripContext.fieldDay));
    expect(contexts, contains(TripContext.cityToField));
  });

  test('setLastTripDestinationId recuerda destino de maleta', () async {
    await repository.setLastTripDestinationId('dest_la_paz');
    expect(await repository.getLastTripDestinationId(), 'dest_la_paz');
  });

  test('setLastPackingDestinationId recuerda el destino para plantillas', () async {
    await repository.setLastPackingDestinationId('dest_rayo_rojo');
    expect(await repository.getLastPackingDestinationId(), 'dest_rayo_rojo');

    await repository.setLastPackingDestinationId(null);
    expect(await repository.getLastPackingDestinationId(), isNull);
  });

  test('wasLegacyDataMigrated es false hasta migrar', () async {
    expect(await repository.wasLegacyDataMigrated(), isFalse);

    await repository.setLegacyDataMigrated(true);
    expect(await repository.wasLegacyDataMigrated(), isTrue);
  });
}
