import 'package:sqflite/sqflite.dart';

import '../database_migration.dart';

class MigrationV3 implements DatabaseMigration {
  static const id = 3;

  @override
  int get version => MigrationV3.id;

  @override
  Future<void> up(Database db) async {
    await db.execute('ALTER TABLE packing_sessions ADD COLUMN travel_date INTEGER');

    await db.execute('''
      UPDATE packing_sessions
      SET travel_date = created_at
      WHERE travel_date IS NULL
    ''');
  }
}
