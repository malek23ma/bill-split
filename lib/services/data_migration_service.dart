import 'dart:io';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../database/supabase_repository.dart';

class DataMigrationService {
  final DatabaseHelper _local;
  final SupabaseRepository _remote;
  static const _uuid = Uuid();

  DataMigrationService(this._local, this._remote);

  /// Check if there's local data to migrate
  Future<Map<String, int>> getLocalDataStats() async {
    final db = await _local.database;
    final households =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM households');
    final bills = await db.rawQuery('SELECT COUNT(*) as cnt FROM bills');
    return {
      'households': (households.first['cnt'] as int?) ?? 0,
      'bills': (bills.first['cnt'] as int?) ?? 0,
    };
  }

  /// Migrate all local data to Supabase.
  /// Yields progress from 0.0 to 1.0.
  Stream<double> migrateLocalData() async* {
    final db = await _local.database;

    // Count total rows for progress
    final households = await db.query('households');
    final members = await db.query('members');
    final recurringBills = await db.query('recurring_bills');
    final bills = await db.query('bills');
    final billItems = await db.query('bill_items');
    final billItemMembers = await db.query('bill_item_members');

    final totalRows = households.length +
        members.length +
        recurringBills.length +
        bills.length +
        billItems.length +
        billItemMembers.length;
    if (totalRows == 0) {
      yield 1.0;
      return;
    }

    int processed = 0;

    // ID mapping: local int → remote UUID
    final idMap = <String, Map<int, String>>{
      'households': {},
      'members': {},
      'recurring_bills': {},
      'bills': {},
      'bill_items': {},
    };

    // 1. Households
    for (final row in households) {
      final localId = row['id'] as int;
      if (row['remote_id'] != null) {
        idMap['households']![localId] = row['remote_id'] as String;
        processed++;
        yield processed / totalRows;
        continue;
      }
      final uuid = _uuid.v4();
      await _remote.upsertHousehold({
        'id': uuid,
        'name': row['name'],
        'currency': row['currency'],
        'created_at': row['created_at'],
      });
      idMap['households']![localId] = uuid;
      await db.update('households', {'remote_id': uuid},
          where: 'id = ?', whereArgs: [localId]);
      processed++;
      yield processed / totalRows;
    }

    // 2. Members
    for (final row in members) {
      final localId = row['id'] as int;
      if (row['remote_id'] != null) {
        idMap['members']![localId] = row['remote_id'] as String;
        processed++;
        yield processed / totalRows;
        continue;
      }
      final uuid = _uuid.v4();
      final householdUuid = idMap['households']![row['household_id'] as int];
      if (householdUuid == null) {
        processed++;
        yield processed / totalRows;
        continue;
      }
      await _remote.upsertMember({
        'id': uuid,
        'household_id': householdUuid,
        'name': row['name'],
        'pin': row['pin'],
        'is_active': (row['is_active'] as int) == 1,
        'is_admin': (row['is_admin'] as int) == 1,
        'created_at': row['created_at'],
      });
      idMap['members']![localId] = uuid;
      await db.update('members', {'remote_id': uuid},
          where: 'id = ?', whereArgs: [localId]);
      processed++;
      yield processed / totalRows;
    }

    // 3. Recurring Bills
    for (final row in recurringBills) {
      final localId = row['id'] as int;
      if (row['remote_id'] != null) {
        idMap['recurring_bills']![localId] = row['remote_id'] as String;
        processed++;
        yield processed / totalRows;
        continue;
      }
      final uuid = _uuid.v4();
      final householdUuid = idMap['households']![row['household_id'] as int];
      final paidByUuid = idMap['members']![row['paid_by_member_id'] as int];
      if (householdUuid == null || paidByUuid == null) {
        processed++;
        yield processed / totalRows;
        continue;
      }
      await _remote.upsertRecurringBill({
        'id': uuid,
        'household_id': householdUuid,
        'paid_by_member_id': paidByUuid,
        'category': row['category'],
        'amount': row['amount'],
        'title': row['title'],
        'frequency': row['frequency'],
        'next_due_date': row['next_due_date'],
        'active': (row['active'] as int) == 1,
      });
      idMap['recurring_bills']![localId] = uuid;
      await db.update('recurring_bills', {'remote_id': uuid},
          where: 'id = ?', whereArgs: [localId]);
      processed++;
      yield processed / totalRows;
    }

    // 4. Bills
    for (final row in bills) {
      final localId = row['id'] as int;
      if (row['remote_id'] != null) {
        idMap['bills']![localId] = row['remote_id'] as String;
        processed++;
        yield processed / totalRows;
        continue;
      }
      final uuid = _uuid.v4();
      final householdUuid = idMap['households']![row['household_id'] as int];
      final enteredByUuid =
          idMap['members']![row['entered_by_member_id'] as int];
      final paidByUuid = idMap['members']![row['paid_by_member_id'] as int];
      if (householdUuid == null ||
          enteredByUuid == null ||
          paidByUuid == null) {
        processed++;
        yield processed / totalRows;
        continue;
      }

      final billData = <String, dynamic>{
        'id': uuid,
        'household_id': householdUuid,
        'entered_by_member_id': enteredByUuid,
        'paid_by_member_id': paidByUuid,
        'bill_type': row['bill_type'],
        'total_amount': row['total_amount'],
        'bill_date': row['bill_date'],
        'created_at': row['created_at'],
        'category': row['category'],
      };

      // Optional FKs
      final recurringId = row['recurring_bill_id'] as int?;
      if (recurringId != null) {
        billData['recurring_bill_id'] =
            idMap['recurring_bills']![recurringId];
      }
      final receiverId = row['receiver_member_id'] as int?;
      if (receiverId != null) {
        billData['receiver_member_id'] = idMap['members']![receiverId];
      }

      await _remote.upsertBill(billData);
      idMap['bills']![localId] = uuid;
      await db.update('bills', {'remote_id': uuid},
          where: 'id = ?', whereArgs: [localId]);

      // Upload photo if exists
      final photoPath = row['photo_path'] as String?;
      if (photoPath != null) {
        try {
          final file = File(photoPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final url =
                await _remote.uploadReceipt(householdUuid, uuid, bytes);
            await db.update('bills', {'photo_url': url},
                where: 'id = ?', whereArgs: [localId]);
          }
        } catch (_) {
          // Skip photo upload errors
        }
      }

      processed++;
      yield processed / totalRows;
    }

    // 5. Bill Items
    for (final row in billItems) {
      final localId = row['id'] as int;
      if (row['remote_id'] != null) {
        idMap['bill_items']![localId] = row['remote_id'] as String;
        processed++;
        yield processed / totalRows;
        continue;
      }
      final uuid = _uuid.v4();
      final billUuid = idMap['bills']![row['bill_id'] as int];
      if (billUuid == null) {
        processed++;
        yield processed / totalRows;
        continue;
      }
      await _remote.upsertBillItem({
        'id': uuid,
        'bill_id': billUuid,
        'name': row['name'],
        'price': row['price'],
        'is_included': (row['is_included'] as int) == 1,
      });
      idMap['bill_items']![localId] = uuid;
      await db.update('bill_items', {'remote_id': uuid},
          where: 'id = ?', whereArgs: [localId]);
      processed++;
      yield processed / totalRows;
    }

    // 6. Bill Item Members
    for (final row in billItemMembers) {
      final localId = row['id'] as int;
      if (row['remote_id'] != null) {
        processed++;
        yield processed / totalRows;
        continue;
      }
      final uuid = _uuid.v4();
      final itemUuid = idMap['bill_items']![row['bill_item_id'] as int];
      final memberUuid = idMap['members']![row['member_id'] as int];
      if (itemUuid == null || memberUuid == null) {
        processed++;
        yield processed / totalRows;
        continue;
      }
      await _remote.upsertBillItemMember({
        'id': uuid,
        'bill_item_id': itemUuid,
        'member_id': memberUuid,
      });
      await db.update('bill_item_members', {'remote_id': uuid},
          where: 'id = ?', whereArgs: [localId]);
      processed++;
      yield processed / totalRows;
    }

    yield 1.0;
  }
}
