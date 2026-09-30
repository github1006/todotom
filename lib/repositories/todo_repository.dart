import '../models/todo_item.dart';

abstract class TodoRepository {
  Future<List<TodoItem>> getAll();

  Future<TodoItem?> findById(String id);

  Future<List<TodoItem>> findPendingByPlace(String placeId);

  Future<void> upsert(TodoItem todo);

  Future<void> upsertAll(List<TodoItem> todos);

  Future<void> replaceAll(List<TodoItem> todos);

  Future<void> delete(String id);

  Future<void> deleteCompleted();

  Future<void> clearPlaceReferences(String placeId);
}
