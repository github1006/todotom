import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/place.dart';
import 'package:todotom/models/todo_item.dart';
import 'package:todotom/repositories/sqlite/sqlite_place_repository.dart';
import 'package:todotom/repositories/sqlite/sqlite_todo_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late SqliteTodoRepository todoRepository;
  late SqlitePlaceRepository placeRepository;

  setUp(() async {
    final database = await createTestDatabase();
    todoRepository = SqliteTodoRepository(database);
    placeRepository = SqlitePlaceRepository(database);
  });

  test('upsert y getAll persisten tareas', () async {
    final todo = TodoItem(id: '1', title: 'Comprar leche');

    await todoRepository.upsert(todo);
    final todos = await todoRepository.getAll();

    expect(todos, hasLength(1));
    expect(todos.first.title, 'Comprar leche');
  });

  test('findPendingByPlace devuelve solo pendientes del lugar', () async {
    await placeRepository.upsert(
      Place(
        id: 'p1',
        name: 'Super',
        latitude: 40.0,
        longitude: -3.0,
      ),
    );

    await todoRepository.upsert(TodoItem(id: '1', title: 'Leche', placeId: 'p1'));
    await todoRepository.upsert(
      TodoItem(id: '2', title: 'Hecha', done: true, placeId: 'p1'),
    );
    await todoRepository.upsert(TodoItem(id: '3', title: 'Otra', placeId: 'p2'));

    final pending = await todoRepository.findPendingByPlace('p1');

    expect(pending, hasLength(1));
    expect(pending.first.title, 'Leche');
  });

  test('deleteCompleted elimina solo completadas', () async {
    await todoRepository.upsert(TodoItem(id: '1', title: 'A', done: true));
    await todoRepository.upsert(TodoItem(id: '2', title: 'B'));

    await todoRepository.deleteCompleted();
    final todos = await todoRepository.getAll();

    expect(todos, hasLength(1));
    expect(todos.first.title, 'B');
  });

  test('clearPlaceReferences quita el lugar de las tareas', () async {
    await todoRepository.upsert(TodoItem(id: '1', title: 'Pernos', placeId: 'p1'));

    await todoRepository.clearPlaceReferences('p1');
    final todo = await todoRepository.findById('1');

    expect(todo?.placeId, isNull);
  });
}
