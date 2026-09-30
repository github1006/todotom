import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/reminder_sound.dart';
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

  test('wasLegacyDataMigrated es false hasta migrar', () async {
    expect(await repository.wasLegacyDataMigrated(), isFalse);

    await repository.setLegacyDataMigrated(true);
    expect(await repository.wasLegacyDataMigrated(), isTrue);
  });
}
