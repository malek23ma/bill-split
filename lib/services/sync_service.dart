import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../database/supabase_repository.dart';
import '../database/sync_queue_helper.dart';
import 'connectivity_service.dart';

class SyncService extends ChangeNotifier {
  final DatabaseHelper _local;
  final SupabaseRepository _remote;
  final SyncQueueHelper _queue;
  final ConnectivityService _connectivity;

  bool _syncing = false;
  String? _deviceId;
  static const _uuid = Uuid();

  bool get syncing => _syncing;

  SyncService(this._local, this._remote, this._queue, this._connectivity);

  /// Get or create a persistent device ID
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('sync_device_id');
    if (_deviceId == null) {
      _deviceId = _uuid.v4();
      await prefs.setString('sync_device_id', _deviceId!);
    }
    return _deviceId!;
  }

  /// Main sync entry point — call on app open and when connectivity restores
  Future<void> sync(int householdId) async {
    if (_syncing || !_connectivity.isOnline) return;

    // Get household remote_id
    final db = await _local.database;
    final rows = await db.query('households',
        where: 'id = ?', whereArgs: [householdId]);
    if (rows.isEmpty) return;
    final remoteId = rows.first['remote_id'] as String?;
    if (remoteId == null) return; // Not synced yet

    _syncing = true;
    notifyListeners();
    try {
      await _pushPendingChanges();
      await _pullRemoteChanges(householdId, remoteId);
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Push: process sync queue FIFO
  Future<void> _pushPendingChanges() async {
    final pending = await _queue.getPending();
    for (final entry in pending) {
      try {
        await _processPushEntry(entry);
        await _queue.remove(entry.id!);
      } catch (e) {
        debugPrint('Push error for ${entry.tableName}/${entry.rowId}: $e');
        break; // Stop on first failure, retry next sync
      }
    }
  }

  Future<void> _processPushEntry(SyncQueueEntry entry) async {
    final db = await _local.database;
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

    switch (entry.operation) {
      case 'insert':
      case 'update':
        // Read the current local row
        final localRows = await db.query(entry.tableName,
            where: 'id = ?', whereArgs: [entry.rowId]);
        if (localRows.isEmpty) return;
        final localRow = localRows.first;

        var remoteId = localRow['remote_id'] as String?;

        // Build cloud payload
        final cloudData = Map<String, dynamic>.from(payload);

        if (remoteId == null) {
          // New row — generate UUID
          remoteId = _uuid.v4();
          cloudData['id'] = remoteId;
        } else {
          cloudData['id'] = remoteId;
        }

        // Remove local-only fields
        cloudData.remove('remote_id');
        // Column name mapping: local SQLite → Supabase
        if (cloudData.containsKey('deleted_by_member_id')) {
          cloudData['deleted_by_user_id'] = cloudData.remove('deleted_by_member_id');
        }

        // Resolve foreign key remote_ids
        await _resolveForeignKeys(db, entry.tableName, cloudData);

        // Upsert to cloud
        await _upsertToCloud(entry.tableName, cloudData);

        // Save remote_id locally
        if (localRow['remote_id'] == null) {
          await db.update(entry.tableName, {'remote_id': remoteId},
              where: 'id = ?', whereArgs: [entry.rowId]);
        }
        break;

      case 'delete':
        final localRows = await db.query(entry.tableName,
            where: 'id = ?', whereArgs: [entry.rowId]);
        final remoteId = localRows.isNotEmpty
            ? localRows.first['remote_id'] as String?
            : payload['remote_id'] as String?;
        if (remoteId != null) {
          await _remote.softDelete(entry.tableName, remoteId);
        }
        break;
    }
  }

  /// Resolve local integer FK references to remote UUIDs
  Future<void> _resolveForeignKeys(
      dynamic db, String tableName, Map<String, dynamic> data) async {
    final fkMappings = <String, String>{
      'household_id': 'households',
      'paid_by_member_id': 'members',
      'entered_by_member_id': 'members',
      'receiver_member_id': 'members',
      'recurring_bill_id': 'recurring_bills',
      'bill_id': 'bills',
      'bill_item_id': 'bill_items',
      'member_id': 'members',
    };

    for (final key in fkMappings.keys) {
      if (data.containsKey(key) && data[key] != null) {
        final localId = data[key];
        if (localId is int) {
          final table = fkMappings[key]!;
          final rows = await db.query(table,
              columns: ['remote_id'],
              where: 'id = ?',
              whereArgs: [localId]);
          if (rows.isNotEmpty && rows.first['remote_id'] != null) {
            data[key] = rows.first['remote_id'];
          }
        }
      }
    }
  }

  Future<void> _upsertToCloud(
      String tableName, Map<String, dynamic> data) async {
    switch (tableName) {
      case 'households':
        await _remote.upsertHousehold(data);
        break;
      case 'members':
        await _remote.upsertMember(data);
        break;
      case 'bills':
        await _remote.upsertBill(data);
        break;
      case 'bill_items':
        await _remote.upsertBillItem(data);
        break;
      case 'bill_item_members':
        await _remote.upsertBillItemMember(data);
        break;
      case 'recurring_bills':
        await _remote.upsertRecurringBill(data);
        break;
    }
  }

  /// Pull: fetch remote changes since last sync
  Future<void> _pullRemoteChanges(
      int localHouseholdId, String remoteHouseholdId) async {
    final deviceId = await _getDeviceId();
    final lastSync =
        await _remote.getSyncTimestamp(deviceId, remoteHouseholdId);
    final db = await _local.database;

    // Pull in dependency order
    await _pullTable(
        db,
        'members',
        await _remote.getMembersSince(remoteHouseholdId, lastSync),
        localHouseholdId);
    await _pullTable(
        db,
        'recurring_bills',
        await _remote.getRecurringBillsSince(remoteHouseholdId, lastSync),
        localHouseholdId);
    await _pullTable(
        db,
        'bills',
        await _remote.getBillsSince(remoteHouseholdId, lastSync),
        localHouseholdId);

    // Bill items and bill item members need special handling (pull per bill)
    // For simplicity, pull all updated bills' items
    final updatedBills =
        await _remote.getBillsSince(remoteHouseholdId, lastSync);
    for (final bill in updatedBills) {
      final billRemoteId = bill['id'] as String;
      final items = await _remote.getBillItemsForBill(billRemoteId);
      await _pullTable(db, 'bill_items', items, localHouseholdId);
      for (final item in items) {
        final itemMembers =
            await _remote.getBillItemMembersForItem(item['id'] as String);
        await _pullTable(
            db, 'bill_item_members', itemMembers, localHouseholdId);
      }
    }

    await _remote.updateSyncTimestamp(deviceId, remoteHouseholdId);
  }

  Future<void> _pullTable(dynamic db, String tableName,
      List<Map<String, dynamic>> remoteRows, int localHouseholdId) async {
    for (final remoteRow in remoteRows) {
      final remoteId = remoteRow['id'] as String;
      final remoteUpdatedAt = remoteRow['updated_at'] as String?;
      final remoteDeletedAt = remoteRow['deleted_at'] as String?;

      // Find local row by remote_id
      final localRows = await db
          .query(tableName, where: 'remote_id = ?', whereArgs: [remoteId]);

      if (remoteDeletedAt != null) {
        // Remote was deleted — delete locally if exists
        if (localRows.isNotEmpty) {
          await db.delete(tableName,
              where: 'remote_id = ?', whereArgs: [remoteId]);
        }
        continue;
      }

      // Convert remote data to local format
      final localData = _remoteToLocal(tableName, remoteRow, localHouseholdId);

      if (localRows.isEmpty) {
        // New row from remote — insert locally
        localData['remote_id'] = remoteId;
        await db.insert(tableName, localData);
      } else {
        // Existing row — check if remote is newer
        final localUpdatedAt = localRows.first['updated_at'] as String?;
        if (localUpdatedAt == null ||
            (remoteUpdatedAt != null &&
                remoteUpdatedAt.compareTo(localUpdatedAt) > 0)) {
          // Remote is newer — update local
          await db.update(tableName, localData,
              where: 'remote_id = ?', whereArgs: [remoteId]);
        }
      }
    }
  }

  /// Convert remote cloud row to local SQLite format
  Map<String, dynamic> _remoteToLocal(
      String tableName, Map<String, dynamic> remote, int localHouseholdId) {
    final data = Map<String, dynamic>.from(remote);

    // Remove cloud-only fields
    data.remove('id'); // local uses auto-increment
    data.remove('deleted_at');

    // Column name mapping: Supabase → local SQLite
    if (data.containsKey('deleted_by_user_id')) {
      data['deleted_by_member_id'] = data.remove('deleted_by_user_id');
    }

    // Store updated_at for conflict resolution
    data['updated_at'] = remote['updated_at'];
    data['remote_id'] = remote['id'];

    // Convert boolean fields (Postgres bool → SQLite int)
    for (final key in ['is_active', 'is_admin', 'is_included', 'active']) {
      if (data.containsKey(key) && data[key] is bool) {
        data[key] = (data[key] as bool) ? 1 : 0;
      }
    }

    // Convert timestamps to ISO strings
    for (final key in ['created_at', 'bill_date', 'next_due_date']) {
      if (data.containsKey(key) && data[key] != null) {
        data[key] = data[key].toString();
      }
    }

    return data;
  }

  /// Enqueue a sync operation (called by providers after local writes)
  Future<void> enqueueOperation(String tableName, int rowId, String operation,
      Map<String, dynamic> payload) async {
    await _queue.enqueue(SyncQueueEntry(
      tableName: tableName,
      rowId: rowId,
      operation: operation,
      payload: jsonEncode(payload),
      createdAt: DateTime.now().toIso8601String(),
    ));

    // Try to push immediately if online
    if (_connectivity.isOnline && !_syncing) {
      _pushPendingChanges();
    }
  }

  /// Upload a receipt photo for a bill
  Future<String?> uploadReceiptIfNeeded(int billId) async {
    if (!_connectivity.isOnline) return null;

    final db = await _local.database;
    final rows = await db.query('bills', where: 'id = ?', whereArgs: [billId]);
    if (rows.isEmpty) return null;

    final bill = rows.first;
    final photoPath = bill['photo_path'] as String?;
    final photoUrl = bill['photo_url'] as String?;
    final remoteId = bill['remote_id'] as String?;
    final householdRemoteId =
        await _getHouseholdRemoteId(db, bill['household_id'] as int);

    if (photoPath != null &&
        photoUrl == null &&
        remoteId != null &&
        householdRemoteId != null) {
      final file = File(photoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final url =
            await _remote.uploadReceipt(householdRemoteId, remoteId, bytes);
        await db.update(
            'bills', {'photo_url': url}, where: 'id = ?', whereArgs: [billId]);
        return url;
      }
    }
    return photoUrl;
  }

  Future<String?> _getHouseholdRemoteId(dynamic db, int householdId) async {
    final rows = await db.query('households',
        columns: ['remote_id'], where: 'id = ?', whereArgs: [householdId]);
    if (rows.isEmpty) return null;
    return rows.first['remote_id'] as String?;
  }

  /// Get pending sync count
  Future<int> pendingCount() => _queue.pendingCount();
}
