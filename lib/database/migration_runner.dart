import 'package:sqflite/sqflite.dart';

import 'database_migration.dart';
import 'migrations/migration_v1.dart';

class MigrationRunner {
  static final List<DatabaseMigration> _migrations = [
    MigrationV1(),
  ];

  static int get latestVersion {
    return _migrations.map((migration) => migration.version).reduce((a, b) => a > b ? a : b);
  }

  static Future<void> run(
    Database db, {
    required int fromVersion,
    required int toVersion,
  }) async {
    for (final migration in _migrations) {
      if (migration.version > fromVersion && migration.version <= toVersion) {
        await migration.up(db);
      }
    }
  }
}
