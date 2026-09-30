import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../models/packing_session.dart';
import '../../models/packing_template_item.dart';
import '../../models/trip_context.dart';
import '../../models/trip_destination.dart';
import '../../utils/date_only.dart';
import '../packing_repository.dart';

class SqlitePackingRepository implements PackingRepository {
  SqlitePackingRepository(this._database);

  final AppDatabase _database;

  Future<Database> get _db => _database.open();

  @override
  Future<List<TripDestination>> getDestinations() async {
    final db = await _db;
    final rows = await db.query('trip_destinations', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_destinationFromRow).toList();
  }

  @override
  Future<void> upsertDestination(TripDestination destination) async {
    final db = await _db;
    await db.insert(
      'trip_destinations',
      {
        'id': destination.id,
        'name': destination.name,
        'notes': destination.notes,
        'place_id': destination.placeId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteDestination(String id) async {
    final db = await _db;
    await db.delete('trip_destinations', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<PackingTemplateItem>> getTemplateItems() async {
    final db = await _db;
    final rows = await db.query(
      'packing_template_items',
      orderBy: 'sort_order ASC, title COLLATE NOCASE ASC',
    );
    return rows.map(_templateFromRow).toList();
  }

  @override
  Future<void> upsertTemplateItem(PackingTemplateItem item) async {
    final db = await _db;
    await db.insert(
      'packing_template_items',
      {
        'id': item.id,
        'title': item.title,
        'destination_id': item.destinationId,
        'trip_contexts': jsonEncode(TripContextStorage.toKeys(item.tripContexts)),
        'sort_order': item.sortOrder,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteTemplateItem(String id) async {
    final db = await _db;
    await db.delete('packing_template_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<String?> getLastUsedTripDestinationId() async {
    final db = await _db;
    final rows = await db.query(
      'packing_sessions',
      columns: ['destination_id'],
      where: 'destination_id IS NOT NULL AND destination_id != ?',
      whereArgs: [''],
      orderBy: 'travel_date DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['destination_id'] as String?;
  }

  String? _normalizedDestinationId(String? destinationId) {
    if (destinationId == null || destinationId.isEmpty) return null;
    return destinationId;
  }

  @override
  Future<PackingSession?> findSessionForDate({
    String? destinationId,
    required DateTime travelDate,
  }) async {
    final db = await _db;
    final storedDate = DateOnly.toStorage(travelDate);
    final destId = _normalizedDestinationId(destinationId);
    final rows = await db.query(
      'packing_sessions',
      where: destId == null
          ? "(destination_id IS NULL OR destination_id = '') AND travel_date = ?"
          : 'destination_id = ? AND travel_date = ?',
      whereArgs: destId == null ? [storedDate] : [destId, storedDate],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _sessionFromRow(rows.first);
  }

  @override
  Future<PackingSession?> getLatestOpenSession({DateTime? travelDate}) async {
    final db = await _db;
    final dateFilter = travelDate != null ? 'AND s.travel_date = ${DateOnly.toStorage(travelDate)}' : '';
    final rows = await db.rawQuery('''
      SELECT s.* FROM packing_sessions s
      WHERE EXISTS (
        SELECT 1 FROM packing_session_items i
        WHERE i.session_id = s.id AND i.done = 0
      )
      $dateFilter
      ORDER BY s.travel_date DESC, s.created_at DESC
      LIMIT 1
    ''');

    if (rows.isEmpty) return null;
    return _sessionFromRow(rows.first);
  }

  @override
  Future<List<PackingSession>> listTripHistory({int limit = 40}) async {
    final db = await _db;
    final rows = await db.query(
      'packing_sessions',
      orderBy: 'travel_date DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<List<PackingSessionItem>> getSessionItems(String sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'packing_session_items',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC, title COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (row) => PackingSessionItem(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            title: row['title'] as String,
            done: (row['done'] as int) == 1,
            sortOrder: row['sort_order'] as int? ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<PackingSession> ensureSession({
    String? destinationId,
    required DateTime travelDate,
    required List<TripContext> tripContexts,
    required List<String> titles,
  }) async {
    final existing = await findSessionForDate(
      destinationId: destinationId,
      travelDate: travelDate,
    );
    if (existing != null) {
      await _syncSessionItems(existing.id, titles);
      await _updateSessionContexts(existing.id, tripContexts);
      return existing;
    }

    return _createSession(
      destinationId: destinationId,
      travelDate: travelDate,
      tripContexts: tripContexts,
      titles: titles,
    );
  }

  Future<PackingSession> _createSession({
    String? destinationId,
    required DateTime travelDate,
    required List<TripContext> tripContexts,
    required List<String> titles,
  }) async {
    final db = await _db;
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    final createdAt = DateTime.now();

    await db.insert('packing_sessions', {
      'id': sessionId,
      'destination_id': _normalizedDestinationId(destinationId),
      'trip_contexts': jsonEncode(TripContextStorage.toKeys(tripContexts)),
      'created_at': createdAt.millisecondsSinceEpoch,
      'travel_date': DateOnly.toStorage(travelDate),
    });

    final batch = db.batch();
    for (var i = 0; i < titles.length; i++) {
      batch.insert('packing_session_items', {
        'id': '${sessionId}_$i',
        'session_id': sessionId,
        'title': titles[i],
        'done': 0,
        'sort_order': i,
      });
    }
    await batch.commit(noResult: true);

    return PackingSession(
      id: sessionId,
      destinationId: destinationId,
      tripContexts: tripContexts,
      createdAt: createdAt,
      travelDate: DateOnly.from(travelDate),
    );
  }

  Future<void> _syncSessionItems(String sessionId, List<String> titles) async {
    final existing = await getSessionItems(sessionId);
    final byTitle = {for (final item in existing) item.title.toLowerCase(): item};

    final db = await _db;
    final batch = db.batch();
    var order = existing.length;

    for (final title in titles) {
      final key = title.toLowerCase();
      if (byTitle.containsKey(key)) continue;

      batch.insert('packing_session_items', {
        'id': '${sessionId}_${DateTime.now().microsecondsSinceEpoch}_$order',
        'session_id': sessionId,
        'title': title,
        'done': 0,
        'sort_order': order,
      });
      order++;
    }

    await batch.commit(noResult: true);
  }

  Future<void> _updateSessionContexts(String sessionId, List<TripContext> tripContexts) async {
    final db = await _db;
    await db.update(
      'packing_sessions',
      {'trip_contexts': jsonEncode(TripContextStorage.toKeys(tripContexts))},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> setSessionItemDone(String itemId, bool done) async {
    final db = await _db;
    await db.update(
      'packing_session_items',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final db = await _db;
    await db.delete('packing_session_items', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('packing_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  TripDestination _destinationFromRow(Map<String, Object?> row) {
    return TripDestination(
      id: row['id'] as String,
      name: row['name'] as String,
      notes: row['notes'] as String?,
      placeId: row['place_id'] as String?,
    );
  }

  PackingTemplateItem _templateFromRow(Map<String, Object?> row) {
    final raw = row['trip_contexts'] as String? ?? '[]';
    final keys = (jsonDecode(raw) as List).cast<String>();
    return PackingTemplateItem(
      id: row['id'] as String,
      title: row['title'] as String,
      destinationId: row['destination_id'] as String?,
      tripContexts: TripContextStorage.fromKeys(keys),
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  PackingSession _sessionFromRow(Map<String, Object?> row) {
    final raw = row['trip_contexts'] as String? ?? '[]';
    final keys = (jsonDecode(raw) as List).cast<String>();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);
    final travelMillis = row['travel_date'] as int? ?? row['created_at'] as int;

    return PackingSession(
      id: row['id'] as String,
      destinationId: row['destination_id'] as String?,
      tripContexts: TripContextStorage.fromKeys(keys),
      createdAt: createdAt,
      travelDate: DateOnly.fromStorage(travelMillis),
    );
  }
}
