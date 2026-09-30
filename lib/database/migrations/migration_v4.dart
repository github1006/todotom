import 'package:sqflite/sqflite.dart';

import '../database_migration.dart';

class MigrationV4 implements DatabaseMigration {
  static const id = 4;

  @override
  int get version => MigrationV4.id;

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      UPDATE packing_sessions
      SET destination_id = NULL
      WHERE destination_id = ''
    ''');

    await _mergeDuplicateSessions(db);

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_packing_sessions_dest_travel_date
      ON packing_sessions(travel_date, IFNULL(destination_id, ''))
    ''');
  }

  Future<void> _mergeDuplicateSessions(Database db) async {
    final rows = await db.query('packing_sessions', orderBy: 'created_at ASC');
    final canonicalByKey = <String, String>{};

    for (final row in rows) {
      final sessionId = row['id'] as String;
      final destinationId = row['destination_id'] as String?;
      final travelDate = row['travel_date'] as int? ?? row['created_at'] as int;
      final key = '${destinationId ?? ''}|$travelDate';

      final keeperId = canonicalByKey[key];
      if (keeperId == null) {
        canonicalByKey[key] = sessionId;
        continue;
      }

      await _mergeSessionInto(db, fromSessionId: sessionId, intoSessionId: keeperId);
      await db.delete('packing_session_items', where: 'session_id = ?', whereArgs: [sessionId]);
      await db.delete('packing_sessions', where: 'id = ?', whereArgs: [sessionId]);
    }
  }

  Future<void> _mergeSessionInto(
    Database db, {
    required String fromSessionId,
    required String intoSessionId,
  }) async {
    final keeperItems = await db.query(
      'packing_session_items',
      where: 'session_id = ?',
      whereArgs: [intoSessionId],
    );
    final byTitle = <String, Map<String, Object?>>{
      for (final row in keeperItems) (row['title'] as String).toLowerCase(): row,
    };

    final dupItems = await db.query(
      'packing_session_items',
      where: 'session_id = ?',
      whereArgs: [fromSessionId],
    );

    var nextOrder = keeperItems.length;
    for (final item in dupItems) {
      final title = item['title'] as String;
      final titleKey = title.toLowerCase();
      final done = (item['done'] as int) == 1;
      final existing = byTitle[titleKey];

      if (existing != null) {
        if (done && (existing['done'] as int) != 1) {
          await db.update(
            'packing_session_items',
            {'done': 1},
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
          existing['done'] = 1;
        }
        continue;
      }

      await db.insert('packing_session_items', {
        'id': '${intoSessionId}_merged_${item['id']}',
        'session_id': intoSessionId,
        'title': title,
        'done': done ? 1 : 0,
        'sort_order': nextOrder,
      });
      nextOrder++;
      byTitle[titleKey] = item;
    }
  }
}
