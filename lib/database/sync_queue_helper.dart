import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class SyncQueueEntry {
  final int? id;
  final String tableName;
  final int rowId;
  final String operation; // 'insert', 'update', 'delete'
  final String payload; // JSON string
  final String createdAt;

  SyncQueueEntry({
    this.id,
    required this.tableName,
    required this.rowId,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'table_name': tableName,
    'row_id': rowId,
    'operation': operation,
    'payload': payload,
    'created_at': createdAt,
  };

  factory SyncQueueEntry.fromMap(Map<String, dynamic> map) => SyncQueueEntry(
    id: map['id'] as int?,
    tableName: map['table_name'] as String,
    rowId: map['row_id'] as int,
    operation: map['operation'] as String,
    payload: map['payload'] as String,
    createdAt: map['created_at'] as String,
  );
}

class SyncQueueHelper {
  final DatabaseHelper _db;

  SyncQueueHelper(this._db);

  Future<void> enqueue(SyncQueueEntry entry) async {
    final db = await _db.database;
    await db.insert('sync_queue', entry.toMap());
  }

  Future<List<SyncQueueEntry>> getPending() async {
    final db = await _db.database;
    final maps = await db.query('sync_queue', orderBy: 'created_at ASC');
    return maps.map(SyncQueueEntry.fromMap).toList();
  }

  Future<void> remove(int id) async {
    final db = await _db.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('sync_queue');
  }

  Future<int> pendingCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
