import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migration_runner.dart';

class AppDatabase {
  AppDatabase({
    DatabaseFactory? databaseFactory,
    String? dbPath,
  })  : _databaseFactory = databaseFactory,
        _dbPath = dbPath;

  final DatabaseFactory? _databaseFactory;
  final String? _dbPath;
  Database? _database;

  DatabaseFactory get _factory => _databaseFactory ?? databaseFactory;

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    final path = _dbPath ?? p.join(await getDatabasesPath(), 'todotom.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: MigrationRunner.latestVersion,
        onCreate: (db, version) async {
          await MigrationRunner.run(db, fromVersion: 0, toVersion: version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await MigrationRunner.run(db, fromVersion: oldVersion, toVersion: newVersion);
        },
      ),
    );

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
