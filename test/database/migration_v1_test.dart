import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todotom/database/migration_runner.dart';
import 'package:todotom/database/migrations/migration_v1.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MigrationV1 crea tablas places, todos y settings', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    await MigrationRunner.run(db, fromVersion: 0, toVersion: MigrationV1.id);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final tableNames = tables.map((row) => row['name'] as String).toList();

    expect(tableNames, containsAll(['places', 'todos', 'settings']));

    await db.close();
  });

  test('MigrationV1 no se ejecuta dos veces si ya está aplicada', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    await MigrationRunner.run(db, fromVersion: 0, toVersion: MigrationV1.id);
    await MigrationRunner.run(db, fromVersion: MigrationV1.id, toVersion: MigrationV1.id);

    final placesCount = await db.rawQuery('SELECT COUNT(*) as c FROM places');
    expect(placesCount.first['c'], 0);

    await db.close();
  });
}
