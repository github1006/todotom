import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:todotom/database/migration_runner.dart';
import 'package:todotom/utils/date_only.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MigrationV4 fusiona sesiones duplicadas mismo destino y fecha', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (database, version) async {
          await MigrationRunner.run(database, fromVersion: 0, toVersion: version);
        },
      ),
    );

    await db.insert('trip_destinations', {'id': 'dest1', 'name': 'Rayo Rojo'});
    final travelDate = DateOnly.toStorage(DateTime(2025, 6, 1));

    await db.insert('packing_sessions', {
      'id': 's1',
      'destination_id': 'dest1',
      'trip_contexts': '[]',
      'created_at': 1000,
      'travel_date': travelDate,
    });
    await db.insert('packing_session_items', {
      'id': 'i1',
      'session_id': 's1',
      'title': 'Pasaporte',
      'done': 1,
      'sort_order': 0,
    });

    await db.insert('packing_sessions', {
      'id': 's2',
      'destination_id': 'dest1',
      'trip_contexts': '[]',
      'created_at': 2000,
      'travel_date': travelDate,
    });
    await db.insert('packing_session_items', {
      'id': 'i2',
      'session_id': 's2',
      'title': 'Botas',
      'done': 0,
      'sort_order': 0,
    });

    await MigrationRunner.run(db, fromVersion: 3, toVersion: 4);

    final sessions = await db.query('packing_sessions');
    expect(sessions.length, 1);
    expect(sessions.first['id'], 's1');

    final items = await db.query('packing_session_items', orderBy: 'sort_order ASC');
    expect(items.length, 2);
    expect(
      items.map((r) => r['title'] as String).toSet(),
      {'Pasaporte', 'Botas'},
    );

    await db.close();
  });
}
