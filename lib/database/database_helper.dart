import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/household.dart';
import '../models/member.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';

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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE households (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
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
        FOREIGN KEY (household_id) REFERENCES households(id),
        FOREIGN KEY (entered_by_member_id) REFERENCES members(id),
        FOREIGN KEY (paid_by_member_id) REFERENCES members(id)
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
    await db.delete('bill_items',
        where: 'bill_id IN (SELECT id FROM bills WHERE household_id = ?)',
        whereArgs: [id]);
    await db.delete('bills', where: 'household_id = ?', whereArgs: [id]);
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
    await db.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  // --- BillItem CRUD ---

  Future<void> insertBillItems(List<BillItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('bill_items', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    final db = await database;
    final maps = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    return maps.map((map) => BillItem.fromMap(map)).toList();
  }
}
