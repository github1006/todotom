import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:todotom/database/migration_runner.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MigrationV3 agrega travel_date a packing_sessions', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: MigrationRunner.latestVersion,
        onCreate: (database, version) async {
          await MigrationRunner.run(database, fromVersion: 0, toVersion: version);
        },
      ),
    );

    final columns = await db.rawQuery('PRAGMA table_info(packing_sessions)');
    final names = columns.map((row) => row['name'] as String).toSet();
    expect(names, contains('travel_date'));

    await db.close();
  });
}
