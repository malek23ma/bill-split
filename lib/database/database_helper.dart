import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/recurring_bill.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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
      version: 4,
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
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        household_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        pin TEXT,
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
        FOREIGN KEY (household_id) REFERENCES households(id),
        FOREIGN KEY (entered_by_member_id) REFERENCES members(id),
        FOREIGN KEY (paid_by_member_id) REFERENCES members(id),
        FOREIGN KEY (recurring_bill_id) REFERENCES recurring_bills(id)
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
        FOREIGN KEY (bill_id) REFERENCES bills(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bill_item_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_item_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
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
        FOREIGN KEY (household_id) REFERENCES households(id),
        FOREIGN KEY (paid_by_member_id) REFERENCES members(id)
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
  }

  Future<void> updateMemberPin(int memberId, String? pin) async {
    final db = await database;
    await db.update(
      'members',
      {'pin': pin},
      where: 'id = ?',
      whereArgs: [memberId],
    );
  }

  // --- Household CRUD ---

  Future<int> insertHousehold(Household household) async {
    final db = await database;
    return await db.insert('households', household.toMap());
  }

  Future<List<Household>> getHouseholds() async {
    final db = await database;
    final maps = await db.query('households', orderBy: 'created_at DESC');
    return maps.map((map) => Household.fromMap(map)).toList();
  }

  Future<void> deleteHousehold(int id) async {
    final db = await database;
    // Delete bill_item_members for all bill items in this household's bills
    await db.delete('bill_item_members',
        where: 'bill_item_id IN (SELECT bi.id FROM bill_items bi JOIN bills b ON bi.bill_id = b.id WHERE b.household_id = ?)',
        whereArgs: [id]);
    await db.delete('bill_items',
        where: 'bill_id IN (SELECT id FROM bills WHERE household_id = ?)',
        whereArgs: [id]);
    await db.delete('bills', where: 'household_id = ?', whereArgs: [id]);
    await db.delete('recurring_bills', where: 'household_id = ?', whereArgs: [id]);
    await db.delete('members', where: 'household_id = ?', whereArgs: [id]);
    await db.delete('households', where: 'id = ?', whereArgs: [id]);
  }

  // --- Member CRUD ---

  Future<int> insertMember(Member member) async {
    final db = await database;
    return await db.insert('members', member.toMap());
  }

  Future<List<Member>> getMembersByHousehold(int householdId) async {
    final db = await database;
    final maps = await db.query(
      'members',
      where: 'household_id = ?',
      whereArgs: [householdId],
    );
    return maps.map((map) => Member.fromMap(map)).toList();
  }

  // --- Bill CRUD ---

  Future<int> insertBill(Bill bill) async {
    final db = await database;
    return await db.insert('bills', bill.toMap());
  }

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

  Future<Bill?> getBill(int id) async {
    final db = await database;
    final maps = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Bill.fromMap(maps.first);
  }

  Future<void> deleteBill(int id) async {
    final db = await database;
    // Delete bill_item_members for all items in this bill
    await db.delete('bill_item_members',
        where: 'bill_item_id IN (SELECT id FROM bill_items WHERE bill_id = ?)',
        whereArgs: [id]);
    await db.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  // --- BillItem CRUD ---

  Future<void> insertBillItems(List<BillItem> items) async {
    final db = await database;
    for (final item in items) {
      final itemId = await db.insert('bill_items', item.toMap());
      if (item.sharedByMemberIds.isNotEmpty) {
        await insertBillItemMembers(itemId, item.sharedByMemberIds);
      }
    }
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    final db = await database;
    final maps = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    final items = <BillItem>[];
    for (final map in maps) {
      final itemId = map['id'] as int;
      final memberIds = await getBillItemMemberIds(itemId);
      items.add(BillItem.fromMap(map, memberIds: memberIds));
    }
    return items;
  }

  // --- BillItemMembers (junction table) ---

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
  }

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

  Future<void> deleteBillItemMembers(int billItemId) async {
    final db = await database;
    await db.delete('bill_item_members',
        where: 'bill_item_id = ?', whereArgs: [billItemId]);
  }

  // --- RecurringBill CRUD ---

  Future<int> insertRecurringBill(RecurringBill recurringBill) async {
    final db = await database;
    return await db.insert('recurring_bills', recurringBill.toMap());
  }

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

  Future<void> updateRecurringBillNextDate(int id, DateTime nextDate) async {
    final db = await database;
    await db.update(
      'recurring_bills',
      {'next_due_date': nextDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deactivateRecurringBill(int id) async {
    final db = await database;
    await db.update(
      'recurring_bills',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Household currency ---

  Future<void> updateHouseholdCurrency(int id, String currency) async {
    final db = await database;
    await db.update(
      'households',
      {'currency': currency},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
