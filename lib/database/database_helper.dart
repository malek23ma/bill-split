import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/recurring_bill.dart';
import 'data_repository.dart';
import 'sync_queue_helper.dart';

class DatabaseHelper implements DataRepository {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  SyncQueueHelper? _syncQueue;

  void setSyncQueue(SyncQueueHelper queue) {
    _syncQueue = queue;
  }

  DatabaseHelper._init();

  Future<void> _enqueueSync(String tableName, int rowId, String operation,
      Map<String, dynamic> payload) async {
    if (_syncQueue == null) return;
    await _syncQueue!.enqueue(SyncQueueEntry(
      tableName: tableName,
      rowId: rowId,
      operation: operation,
      payload: jsonEncode(payload),
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bill_split.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE households (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'TRY',
        created_at TEXT NOT NULL,
        remote_id TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        household_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        pin TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_admin INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT '',
        remote_id TEXT,
        updated_at TEXT,
        FOREIGN KEY (household_id) REFERENCES households(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        household_id INTEGER NOT NULL,
        entered_by_member_id INTEGER NOT NULL,
        paid_by_member_id INTEGER NOT NULL,
        bill_type TEXT NOT NULL,
        total_amount REAL NOT NULL,
        photo_path TEXT,
        bill_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'other',
        recurring_bill_id INTEGER,
        receiver_member_id INTEGER,
        remote_id TEXT,
        updated_at TEXT,
        photo_url TEXT,
        deleted_by_member_id INTEGER,
        FOREIGN KEY (household_id) REFERENCES households(id),
        FOREIGN KEY (entered_by_member_id) REFERENCES members(id),
        FOREIGN KEY (paid_by_member_id) REFERENCES members(id),
        FOREIGN KEY (recurring_bill_id) REFERENCES recurring_bills(id),
        FOREIGN KEY (receiver_member_id) REFERENCES members(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        is_included INTEGER NOT NULL DEFAULT 1,
        split_percent INTEGER NOT NULL DEFAULT 50,
        remote_id TEXT,
        updated_at TEXT,
        FOREIGN KEY (bill_id) REFERENCES bills(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bill_item_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_item_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        remote_id TEXT,
        FOREIGN KEY (bill_item_id) REFERENCES bill_items(id),
        FOREIGN KEY (member_id) REFERENCES members(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        household_id INTEGER NOT NULL,
        paid_by_member_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        title TEXT NOT NULL,
        frequency TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        remote_id TEXT,
        updated_at TEXT,
        FOREIGN KEY (household_id) REFERENCES households(id),
        FOREIGN KEY (paid_by_member_id) REFERENCES members(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cols = await db.rawQuery('PRAGMA table_info(bills)');
      final hasCategory = cols.any((c) => c['name'] == 'category');
      if (!hasCategory) {
        await db.execute("ALTER TABLE bills ADD COLUMN category TEXT NOT NULL DEFAULT 'other'");
      }
    }
    if (oldVersion < 3) {
      final cols = await db.rawQuery('PRAGMA table_info(members)');
      final hasPin = cols.any((c) => c['name'] == 'pin');
      if (!hasPin) {
        await db.execute("ALTER TABLE members ADD COLUMN pin TEXT");
      }
    }
    if (oldVersion < 4) {
      // Add currency to households
      await db.execute("ALTER TABLE households ADD COLUMN currency TEXT NOT NULL DEFAULT 'TRY'");

      // Add recurring_bill_id to bills
      await db.execute("ALTER TABLE bills ADD COLUMN recurring_bill_id INTEGER");

      // Create bill_item_members junction table
      await db.execute('''
        CREATE TABLE bill_item_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bill_item_id INTEGER NOT NULL,
          member_id INTEGER NOT NULL,
          FOREIGN KEY (bill_item_id) REFERENCES bill_items(id),
          FOREIGN KEY (member_id) REFERENCES members(id)
        )
      ''');

      // Create recurring_bills table
      await db.execute('''
        CREATE TABLE recurring_bills (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          household_id INTEGER NOT NULL,
          paid_by_member_id INTEGER NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          title TEXT NOT NULL,
          frequency TEXT NOT NULL,
          next_due_date TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (household_id) REFERENCES households(id),
          FOREIGN KEY (paid_by_member_id) REFERENCES members(id)
        )
      ''');

      // Migrate existing split_percent data to bill_item_members junction table.
      // For each bill item, look up the bill's household members and assign them
      // based on the old split_percent logic (2-person household).
      final billItems = await db.rawQuery('''
        SELECT bi.id AS bill_item_id, bi.split_percent, b.household_id, b.paid_by_member_id
        FROM bill_items bi
        JOIN bills b ON bi.bill_id = b.id
      ''');

      for (final item in billItems) {
        final householdId = item['household_id'] as int;
        final splitPercent = item['split_percent'] as int;
        final members = await db.query('members',
            where: 'household_id = ?', whereArgs: [householdId]);

        if (members.isEmpty) continue;

        if (splitPercent == 100) {
          // Item assigned to payer only - find payer among members
          final payerId = item['paid_by_member_id'] as int;
          await db.insert('bill_item_members', {
            'bill_item_id': item['bill_item_id'],
            'member_id': payerId,
          });
        } else {
          // Shared among all household members (50/50 or any shared split)
          for (final member in members) {
            await db.insert('bill_item_members', {
              'bill_item_id': item['bill_item_id'],
              'member_id': member['id'],
            });
          }
        }
      }
    }
    if (oldVersion < 5) {
      // Add receiver_member_id for pair-based settlements
      await db.execute("ALTER TABLE bills ADD COLUMN receiver_member_id INTEGER");
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE members ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1");
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE members ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0");
      // Set the first (lowest ID) member per household as admin
      await db.execute('''
        UPDATE members SET is_admin = 1
        WHERE id IN (
          SELECT MIN(id) FROM members GROUP BY household_id
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute("ALTER TABLE members ADD COLUMN created_at TEXT NOT NULL DEFAULT ''");
      // Backfill existing members with their household's created_at
      await db.execute('''
        UPDATE members SET created_at = (
          SELECT h.created_at FROM households h WHERE h.id = members.household_id
        )
        WHERE created_at = ''
      ''');
    }
    if (oldVersion < 9) {
      // Fix v8 backfill: members who have never paid or shared any bill
      // are likely recently-added and should get current timestamp instead
      // of the household's creation date.
      final now = DateTime.now().toIso8601String();
      await db.execute('''
        UPDATE members SET created_at = ?
        WHERE id NOT IN (
          SELECT DISTINCT paid_by_member_id FROM bills
        )
        AND id NOT IN (
          SELECT DISTINCT bim.member_id FROM bill_item_members bim
        )
      ''', [now]);
    }
    if (oldVersion < 10) {
      // Add remote_id (UUID) to all synced tables
      await db.execute("ALTER TABLE households ADD COLUMN remote_id TEXT");
      await db.execute("ALTER TABLE members ADD COLUMN remote_id TEXT");
      await db.execute("ALTER TABLE bills ADD COLUMN remote_id TEXT");
      await db.execute("ALTER TABLE bills ADD COLUMN photo_url TEXT");
      await db.execute("ALTER TABLE bill_items ADD COLUMN remote_id TEXT");
      await db.execute("ALTER TABLE bill_item_members ADD COLUMN remote_id TEXT");
      await db.execute("ALTER TABLE recurring_bills ADD COLUMN remote_id TEXT");
      await db.execute("ALTER TABLE bills ADD COLUMN deleted_by_member_id INTEGER");

      // Add updated_at to all synced tables for conflict resolution
      await db.execute("ALTER TABLE households ADD COLUMN updated_at TEXT");
      await db.execute("ALTER TABLE members ADD COLUMN updated_at TEXT");
      await db.execute("ALTER TABLE bills ADD COLUMN updated_at TEXT");
      await db.execute("ALTER TABLE bill_items ADD COLUMN updated_at TEXT");
      await db.execute("ALTER TABLE recurring_bills ADD COLUMN updated_at TEXT");

      // Sync queue table
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          row_id INTEGER NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  @override
  Future<void> updateMemberPin(int memberId, String? pin) async {
    final db = await database;
    await db.update(
      'members',
      {'pin': pin},
      where: 'id = ?',
      whereArgs: [memberId],
    );
    await _enqueueSync('members', memberId, 'update', {'pin': pin});
  }

  @override
  Future<void> updateMemberName(int memberId, String name) async {
    final db = await database;
    await db.update('members', {'name': name}, where: 'id = ?', whereArgs: [memberId]);
    await _enqueueSync('members', memberId, 'update', {'name': name});
  }

  @override
  Future<void> setMemberActive(int memberId, bool active) async {
    final db = await database;
    await db.update('members', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [memberId]);
    await _enqueueSync('members', memberId, 'update', {'is_active': active ? 1 : 0});
  }

  // --- Household CRUD ---

  @override
  Future<int> insertHousehold(Household household) async {
    final db = await database;
    final id = await db.insert('households', household.toMap());
    await _enqueueSync('households', id, 'insert', household.toMap());
    return id;
  }

  @override
  Future<int> createHouseholdWithMembers(String name, List<String> memberNames) async {
    final db = await database;
    late int householdId;
    final memberIds = <int>[];
    await db.transaction((txn) async {
      householdId = await txn.insert('households', Household(name: name).toMap());
      for (int i = 0; i < memberNames.length; i++) {
        final member = Member(
          householdId: householdId,
          name: memberNames[i],
          isAdmin: i == 0, // first member is admin
        );
        final memberId = await txn.insert('members', member.toMap());
        memberIds.add(memberId);
      }
    });
    await _enqueueSync('households', householdId, 'insert', Household(name: name).toMap());
    for (int i = 0; i < memberNames.length; i++) {
      final member = Member(
        householdId: householdId,
        name: memberNames[i],
        isAdmin: i == 0,
      );
      await _enqueueSync('members', memberIds[i], 'insert', member.toMap());
    }
    return householdId;
  }

  @override
  Future<List<Household>> getHouseholds() async {
    final db = await database;
    final maps = await db.query('households', orderBy: 'created_at DESC');
    return maps.map((map) => Household.fromMap(map)).toList();
  }

  @override
  Future<void> deleteHousehold(int id) async {
    final db = await database;
    // Capture remote_id before deleting
    final household = await db.query('households', where: 'id = ?', whereArgs: [id]);
    await db.transaction((txn) async {
      await txn.delete('bill_item_members',
          where: 'bill_item_id IN (SELECT bi.id FROM bill_items bi JOIN bills b ON bi.bill_id = b.id WHERE b.household_id = ?)',
          whereArgs: [id]);
      await txn.delete('bill_items',
          where: 'bill_id IN (SELECT id FROM bills WHERE household_id = ?)',
          whereArgs: [id]);
      await txn.delete('bills', where: 'household_id = ?', whereArgs: [id]);
      await txn.delete('recurring_bills', where: 'household_id = ?', whereArgs: [id]);
      await txn.delete('members', where: 'household_id = ?', whereArgs: [id]);
      await txn.delete('households', where: 'id = ?', whereArgs: [id]);
    });
    await _enqueueSync('households', id, 'delete', {
      'remote_id': household.isNotEmpty ? household.first['remote_id'] : null,
    });
  }

  // --- Member CRUD ---

  @override
  Future<int> insertMember(Member member) async {
    final db = await database;
    final id = await db.insert('members', member.toMap());
    await _enqueueSync('members', id, 'insert', member.toMap());
    return id;
  }

  @override
  Future<List<Member>> getMembersByHousehold(int householdId) async {
    final db = await database;
    final maps = await db.query(
      'members',
      where: 'household_id = ? AND is_active = 1',
      whereArgs: [householdId],
    );
    return maps.map((map) => Member.fromMap(map)).toList();
  }

  @override
  Future<List<Member>> getAllMembersByHousehold(int householdId) async {
    final db = await database;
    final maps = await db.query(
      'members',
      where: 'household_id = ?',
      whereArgs: [householdId],
    );
    return maps.map((map) => Member.fromMap(map)).toList();
  }

  // --- Bill CRUD ---

  @override
  Future<int> insertBill(Bill bill) async {
    final db = await database;
    final id = await db.insert('bills', bill.toMap());
    await _enqueueSync('bills', id, 'insert', bill.toMap());
    return id;
  }

  @override
  Future<List<Bill>> getBillsByHousehold(int householdId) async {
    final db = await database;
    final maps = await db.query(
      'bills',
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'bill_date DESC',
    );
    return maps.map((map) => Bill.fromMap(map)).toList();
  }

  @override
  Future<Bill?> getBill(int id) async {
    final db = await database;
    final maps = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Bill.fromMap(maps.first);
  }

  @override
  Future<void> deleteBill(int id) async {
    final db = await database;
    // Capture remote_id before deleting
    final bill = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    await db.transaction((txn) async {
      await txn.delete('bill_item_members',
          where: 'bill_item_id IN (SELECT id FROM bill_items WHERE bill_id = ?)',
          whereArgs: [id]);
      await txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
      await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
    });
    await _enqueueSync('bills', id, 'delete', {
      'remote_id': bill.isNotEmpty ? bill.first['remote_id'] : null,
    });
  }

  // --- BillItem CRUD ---

  @override
  Future<void> insertBillItems(List<BillItem> items) async {
    final db = await database;
    final insertedIds = <int>[];
    await db.transaction((txn) async {
      for (final item in items) {
        final itemId = await txn.insert('bill_items', item.toMap());
        insertedIds.add(itemId);
        if (item.sharedByMemberIds.isNotEmpty) {
          final batch = txn.batch();
          for (final memberId in item.sharedByMemberIds) {
            batch.insert('bill_item_members', {
              'bill_item_id': itemId,
              'member_id': memberId,
            });
          }
          await batch.commit(noResult: true);
        }
      }
    });
    for (int i = 0; i < items.length; i++) {
      final payload = items[i].toMap();
      payload['shared_by_member_ids'] = items[i].sharedByMemberIds;
      await _enqueueSync('bill_items', insertedIds[i], 'insert', payload);
    }
  }

  @override
  Future<List<BillItem>> getBillItems(int billId) async {
    final db = await database;
    final maps = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    if (maps.isEmpty) return [];

    // Single query to get all member assignments for this bill's items
    final itemIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(itemIds.length, '?').join(',');
    final memberMaps = await db.rawQuery(
      'SELECT bill_item_id, member_id FROM bill_item_members WHERE bill_item_id IN ($placeholders)',
      itemIds,
    );

    // Group member IDs by bill_item_id
    final membersByItem = <int, List<int>>{};
    for (final row in memberMaps) {
      final itemId = row['bill_item_id'] as int;
      final memberId = row['member_id'] as int;
      (membersByItem[itemId] ??= []).add(memberId);
    }

    return maps.map((map) {
      final itemId = map['id'] as int;
      return BillItem.fromMap(map, memberIds: membersByItem[itemId] ?? []);
    }).toList();
  }

  // --- BillItemMembers (junction table) ---

  @override
  Future<void> insertBillItemMembers(int billItemId, List<int> memberIds) async {
    final db = await database;
    final batch = db.batch();
    for (final memberId in memberIds) {
      batch.insert('bill_item_members', {
        'bill_item_id': billItemId,
        'member_id': memberId,
      });
    }
    await batch.commit(noResult: true);
    await _enqueueSync('bill_item_members', billItemId, 'insert', {
      'bill_item_id': billItemId,
      'member_ids': memberIds,
    });
  }

  @override
  Future<List<int>> getBillItemMemberIds(int billItemId) async {
    final db = await database;
    final maps = await db.query(
      'bill_item_members',
      columns: ['member_id'],
      where: 'bill_item_id = ?',
      whereArgs: [billItemId],
    );
    return maps.map((m) => m['member_id'] as int).toList();
  }

  @override
  Future<void> deleteBillItemMembers(int billItemId) async {
    final db = await database;
    await db.delete('bill_item_members',
        where: 'bill_item_id = ?', whereArgs: [billItemId]);
    await _enqueueSync('bill_item_members', billItemId, 'delete', {
      'bill_item_id': billItemId,
    });
  }

  // --- RecurringBill CRUD ---

  @override
  Future<int> insertRecurringBill(RecurringBill recurringBill) async {
    final db = await database;
    final id = await db.insert('recurring_bills', recurringBill.toMap());
    await _enqueueSync('recurring_bills', id, 'insert', recurringBill.toMap());
    return id;
  }

  @override
  Future<List<RecurringBill>> getRecurringBillsByHousehold(int householdId) async {
    final db = await database;
    final maps = await db.query(
      'recurring_bills',
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'next_due_date ASC',
    );
    return maps.map((map) => RecurringBill.fromMap(map)).toList();
  }

  @override
  Future<List<RecurringBill>> getDueRecurringBills(int householdId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'recurring_bills',
      where: 'household_id = ? AND active = 1 AND next_due_date <= ?',
      whereArgs: [householdId, now],
      orderBy: 'next_due_date ASC',
    );
    return maps.map((map) => RecurringBill.fromMap(map)).toList();
  }

  @override
  Future<void> updateRecurringBillNextDate(int id, DateTime nextDate) async {
    final db = await database;
    await db.update(
      'recurring_bills',
      {'next_due_date': nextDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('recurring_bills', id, 'update', {
      'next_due_date': nextDate.toIso8601String(),
    });
  }

  @override
  Future<void> deactivateRecurringBill(int id) async {
    final db = await database;
    await db.update(
      'recurring_bills',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('recurring_bills', id, 'update', {'active': 0});
  }

  @override
  Future<void> reactivateRecurringBill(int id) async {
    final db = await database;
    await db.update('recurring_bills', {'active': 1}, where: 'id = ?', whereArgs: [id]);
    await _enqueueSync('recurring_bills', id, 'update', {'active': 1});
  }

  @override
  Future<void> updateRecurringBill(RecurringBill bill) async {
    final db = await database;
    await db.update('recurring_bills', bill.toMap(), where: 'id = ?', whereArgs: [bill.id]);
    await _enqueueSync('recurring_bills', bill.id!, 'update', bill.toMap());
  }

  @override
  Future<void> deleteRecurringBillPermanently(int id) async {
    final db = await database;
    // Capture remote_id before deleting
    final rb = await db.query('recurring_bills', where: 'id = ?', whereArgs: [id]);
    await db.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
    await _enqueueSync('recurring_bills', id, 'delete', {
      'remote_id': rb.isNotEmpty ? rb.first['remote_id'] : null,
    });
  }

  // --- Member date fix ---

  /// Fix created_at for members who have zero bill participation.
  /// These members were added after all existing bills and should not
  /// be included in historical quick bill splits.
  @override
  Future<void> fixNewMemberDates(int householdId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.execute('''
      UPDATE members SET created_at = ?
      WHERE household_id = ?
      AND id NOT IN (
        SELECT DISTINCT paid_by_member_id FROM bills WHERE household_id = ?
      )
      AND id NOT IN (
        SELECT DISTINCT bim.member_id
        FROM bill_item_members bim
        JOIN bill_items bi ON bim.bill_item_id = bi.id
        JOIN bills b ON bi.bill_id = b.id
        WHERE b.household_id = ?
      )
    ''', [now, householdId, householdId, householdId]);
  }

  // --- Household currency ---

  @override
  Future<void> updateHouseholdCurrency(int id, String currency) async {
    final db = await database;
    await db.update(
      'households',
      {'currency': currency},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueSync('households', id, 'update', {'currency': currency});
  }
}
