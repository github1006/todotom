import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todotom/database/app_database.dart';

Future<AppDatabase> createTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final database = AppDatabase(
    databaseFactory: databaseFactoryFfi,
    dbPath: ':memory:todotom_${DateTime.now().microsecondsSinceEpoch}',
  );
  await database.open();
  return database;
}
