import 'package:sqflite/sqflite.dart';

import '../database_migration.dart';

class MigrationV2 implements DatabaseMigration {
  static const id = 2;

  @override
  int get version => MigrationV2.id;

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE trip_destinations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        notes TEXT,
        place_id TEXT,
        FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE packing_template_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        destination_id TEXT,
        trip_contexts TEXT NOT NULL DEFAULT '[]',
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (destination_id) REFERENCES trip_destinations(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE packing_sessions (
        id TEXT PRIMARY KEY,
        destination_id TEXT,
        trip_contexts TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (destination_id) REFERENCES trip_destinations(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE packing_session_items (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES packing_sessions(id) ON DELETE CASCADE
      )
    ''');
  }
}
