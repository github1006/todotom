import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:todotom/database/migration_runner.dart';
import 'package:todotom/database/migrations/migration_v2.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MigrationV2 crea tablas de maleta', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: MigrationRunner.latestVersion,
        onCreate: (database, version) async {
          await MigrationRunner.run(database, fromVersion: 0, toVersion: version);
        },
      ),
    );

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND (name LIKE 'packing%' OR name='trip_destinations')",
    );

    final names = tables.map((row) => row['name'] as String).toSet();
    expect(names, contains('trip_destinations'));
    expect(names, contains('packing_template_items'));
    expect(names, contains('packing_sessions'));
    expect(names, contains('packing_session_items'));

    await db.close();
  });
}
