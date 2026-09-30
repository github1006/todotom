import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../models/todo_item.dart';
import '../todo_repository.dart';

class SqliteTodoRepository implements TodoRepository {
  SqliteTodoRepository(this._database);

  final AppDatabase _database;

  Future<Database> get _db => _database.open();

  @override
  Future<List<TodoItem>> getAll() async {
    final db = await _db;
    final rows = await db.query('todos', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<TodoItem?> findById(String id) async {
    final db = await _db;
    final rows = await db.query('todos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<TodoItem>> findPendingByPlace(String placeId) async {
    final db = await _db;
    final rows = await db.query(
      'todos',
      where: 'place_id = ? AND done = 0',
      whereArgs: [placeId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsert(TodoItem todo) async {
    final db = await _db;
    await db.insert('todos', _toRow(todo), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> upsertAll(List<TodoItem> todos) async {
    final db = await _db;
    final batch = db.batch();
    for (final todo in todos) {
      batch.insert('todos', _toRow(todo), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> replaceAll(List<TodoItem> todos) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('todos');
      for (final todo in todos) {
        await txn.insert('todos', _toRow(todo));
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteCompleted() async {
    final db = await _db;
    await db.delete('todos', where: 'done = 1');
  }

  @override
  Future<void> clearPlaceReferences(String placeId) async {
    final db = await _db;
    await db.update('todos', {'place_id': null}, where: 'place_id = ?', whereArgs: [placeId]);
  }

  Map<String, Object?> _toRow(TodoItem todo) {
    return {
      'id': todo.id,
      'title': todo.title,
      'done': todo.done ? 1 : 0,
      'place_id': todo.placeId,
      'created_at': todo.createdAt.millisecondsSinceEpoch,
    };
  }

  TodoItem _fromRow(Map<String, Object?> row) {
    return TodoItem(
      id: row['id']! as String,
      title: row['title']! as String,
      done: (row['done']! as int) == 1,
      placeId: row['place_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    );
  }
}
