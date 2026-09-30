import 'package:sqflite/sqflite.dart';

abstract class DatabaseMigration {
  int get version;

  Future<void> up(Database db);
}
