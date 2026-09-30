import 'package:sqflite/sqflite.dart';

import '../database_migration.dart';

class MigrationV1 implements DatabaseMigration {
  static const id = 1;

  @override
  int get version => MigrationV1.id;

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE places (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius_meters REAL NOT NULL DEFAULT 250
      )
    ''');

    await db.execute('''
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        place_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
