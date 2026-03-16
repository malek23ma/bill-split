# Bill Split v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the 2-person bill splitter into a multi-member household finance app with recurring bills, insights, export, currency support, and cloud sync.

**Architecture:** Extend existing Provider + SQLite architecture. DB migration v4 adds junction table for multi-member splits, recurring_bills table, and currency column. New InsightsScreen added via BottomNavigationBar on HomeScreen. Balance calculation changes from percentage-based to count-based per-member sharing. Local-first, Supabase sync added in Phase 4.

**Tech Stack:** Flutter 3.41, Provider, SQLite (sqflite), Google Fonts (Lexend), Material 3, share_plus, csv, pdf, Supabase

---

## Phase 1 — Multi-Member Foundation

### Task 1: Update Household model — add currency field

**Files:**
- Modify: `lib/models/household.dart`

**Step 1:** Update `Household` class to add `currency` field:

```dart
class Household {
  final int? id;
  final String name;
  final String currency;
  final DateTime createdAt;

  Household({
    this.id,
    required this.name,
    this.currency = 'TRY',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Household.fromMap(Map<String, dynamic> map) {
    return Household(
      id: map['id'] as int?,
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'TRY',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
```

**Step 2:** Verify no compile errors: `flutter analyze`

---

### Task 2: Update Bill model — add recurring_bill_id field

**Files:**
- Modify: `lib/models/bill.dart`

**Step 1:** Add `recurringBillId` field:

```dart
class Bill {
  final int? id;
  final int householdId;
  final int enteredByMemberId;
  final int paidByMemberId;
  final String billType;
  final double totalAmount;
  final String? photoPath;
  final DateTime billDate;
  final DateTime createdAt;
  final String category;
  final int? recurringBillId;

  Bill({
    this.id,
    required this.householdId,
    required this.enteredByMemberId,
    required this.paidByMemberId,
    required this.billType,
    required this.totalAmount,
    this.photoPath,
    required this.billDate,
    DateTime? createdAt,
    this.category = 'other',
    this.recurringBillId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'entered_by_member_id': enteredByMemberId,
      'paid_by_member_id': paidByMemberId,
      'bill_type': billType,
      'total_amount': totalAmount,
      'photo_path': photoPath,
      'bill_date': billDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'category': category,
      'recurring_bill_id': recurringBillId,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      enteredByMemberId: map['entered_by_member_id'] as int,
      paidByMemberId: map['paid_by_member_id'] as int,
      billType: map['bill_type'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      photoPath: map['photo_path'] as String?,
      billDate: DateTime.parse(map['bill_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      category: map['category'] as String? ?? 'other',
      recurringBillId: map['recurring_bill_id'] as int?,
    );
  }
}
```

---

### Task 3: Update BillItem model — remove splitPercent, add sharedByMemberIds

**Files:**
- Modify: `lib/models/bill_item.dart`

**Step 1:** Replace `splitPercent` with `sharedByMemberIds`:

```dart
class BillItem {
  final int? id;
  final int billId;
  final String name;
  final double price;
  final bool isIncluded;
  final List<int> sharedByMemberIds;

  BillItem({
    this.id,
    required this.billId,
    required this.name,
    required this.price,
    this.isIncluded = true,
    this.sharedByMemberIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_id': billId,
      'name': name,
      'price': price,
      'is_included': isIncluded ? 1 : 0,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map, {List<int>? memberIds}) {
    return BillItem(
      id: map['id'] as int?,
      billId: map['bill_id'] as int,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      isIncluded: (map['is_included'] as int) == 1,
      sharedByMemberIds: memberIds ?? [],
    );
  }

  BillItem copyWith({
    int? id,
    int? billId,
    String? name,
    double? price,
    bool? isIncluded,
    List<int>? sharedByMemberIds,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      price: price ?? this.price,
      isIncluded: isIncluded ?? this.isIncluded,
      sharedByMemberIds: sharedByMemberIds ?? this.sharedByMemberIds,
    );
  }
}
```

Note: `toMap()` no longer includes `split_percent`. The `sharedByMemberIds` is stored in the `bill_item_members` junction table, not in this table directly.

---

### Task 4: Create RecurringBill model

**Files:**
- Create: `lib/models/recurring_bill.dart`

**Step 1:** Create the model:

```dart
class RecurringBill {
  final int? id;
  final int householdId;
  final int paidByMemberId;
  final String category;
  final double amount;
  final String title;
  final String frequency; // 'weekly', 'monthly', 'yearly'
  final DateTime nextDueDate;
  final bool active;

  RecurringBill({
    this.id,
    required this.householdId,
    required this.paidByMemberId,
    required this.category,
    required this.amount,
    required this.title,
    required this.frequency,
    required this.nextDueDate,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'paid_by_member_id': paidByMemberId,
      'category': category,
      'amount': amount,
      'title': title,
      'frequency': frequency,
      'next_due_date': nextDueDate.toIso8601String(),
      'active': active ? 1 : 0,
    };
  }

  factory RecurringBill.fromMap(Map<String, dynamic> map) {
    return RecurringBill(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      paidByMemberId: map['paid_by_member_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      frequency: map['frequency'] as String,
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      active: (map['active'] as int) == 1,
    );
  }

  /// Calculate the next due date after confirming the current one
  DateTime getNextDueDate() {
    switch (frequency) {
      case 'weekly':
        return nextDueDate.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(nextDueDate.year + 1, nextDueDate.month, nextDueDate.day);
      case 'monthly':
      default:
        final nextMonth = nextDueDate.month == 12 ? 1 : nextDueDate.month + 1;
        final nextYear = nextDueDate.month == 12 ? nextDueDate.year + 1 : nextDueDate.year;
        return DateTime(nextYear, nextMonth, nextDueDate.day);
    }
  }
}
```

---

### Task 5: Database migration v3 → v4

**Files:**
- Modify: `lib/database/database_helper.dart`

**Step 1:** Update database version to 4 and modify `_onCreate` and `_onUpgrade`:

In `_initDB`, change `version: 3` to `version: 4`.

**Step 2:** Update `_onCreate` to include all new tables and columns for fresh installs:

- `households` table: add `currency TEXT NOT NULL DEFAULT 'TRY'`
- `bills` table: add `recurring_bill_id INTEGER`
- `bill_items` table: keep `split_percent` column for backward compat (not used for new bills, but needed for migration read)
- Add new `bill_item_members` table
- Add new `recurring_bills` table

**Step 3:** Update `_onUpgrade` to add migration for `oldVersion < 4`:

```dart
if (oldVersion < 4) {
  // Add currency to households
  final hCols = await db.rawQuery('PRAGMA table_info(households)');
  if (!hCols.any((c) => c['name'] == 'currency')) {
    await db.execute("ALTER TABLE households ADD COLUMN currency TEXT NOT NULL DEFAULT 'TRY'");
  }

  // Add recurring_bill_id to bills
  final bCols = await db.rawQuery('PRAGMA table_info(bills)');
  if (!bCols.any((c) => c['name'] == 'recurring_bill_id')) {
    await db.execute("ALTER TABLE bills ADD COLUMN recurring_bill_id INTEGER");
  }

  // Create bill_item_members junction table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS bill_item_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_item_id INTEGER NOT NULL,
      member_id INTEGER NOT NULL,
      FOREIGN KEY (bill_item_id) REFERENCES bill_items(id),
      FOREIGN KEY (member_id) REFERENCES members(id)
    )
  ''');

  // Create recurring_bills table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS recurring_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER NOT NULL,
      paid_by_member_id INTEGER NOT NULL,
      category TEXT NOT NULL DEFAULT 'other',
      amount REAL NOT NULL,
      title TEXT NOT NULL,
      frequency TEXT NOT NULL DEFAULT 'monthly',
      next_due_date TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (household_id) REFERENCES households(id),
      FOREIGN KEY (paid_by_member_id) REFERENCES members(id)
    )
  ''');

  // Migrate existing bill_items split_percent data to bill_item_members
  // We need to figure out the two members per household for old bills
  final allBills = await db.query('bills');
  for (final billMap in allBills) {
    if (billMap['bill_type'] == 'settlement' || billMap['bill_type'] == 'quick') continue;

    final billId = billMap['id'] as int;
    final householdId = billMap['household_id'] as int;
    final payerId = billMap['paid_by_member_id'] as int;

    final members = await db.query('members', where: 'household_id = ?', whereArgs: [householdId]);
    final memberIds = members.map((m) => m['id'] as int).toList();

    final items = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
    for (final item in items) {
      final itemId = item['id'] as int;
      final splitPercent = item['split_percent'] as int;

      if (splitPercent == 100) {
        // Mine — only the payer
        await db.insert('bill_item_members', {'bill_item_id': itemId, 'member_id': payerId});
      } else if (splitPercent == 0) {
        // Yours — only the other member(s)
        for (final mid in memberIds) {
          if (mid != payerId) {
            await db.insert('bill_item_members', {'bill_item_id': itemId, 'member_id': mid});
          }
        }
      } else {
        // Split — all members
        for (final mid in memberIds) {
          await db.insert('bill_item_members', {'bill_item_id': itemId, 'member_id': mid});
        }
      }
    }
  }
}
```

**Step 4:** Add new CRUD methods to `DatabaseHelper`:

```dart
// --- BillItemMembers CRUD ---

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
    where: 'bill_item_id = ?',
    whereArgs: [billItemId],
  );
  return maps.map((m) => m['member_id'] as int).toList();
}

Future<void> deleteBillItemMembers(int billItemId) async {
  final db = await database;
  await db.delete('bill_item_members', where: 'bill_item_id = ?', whereArgs: [billItemId]);
}

// --- RecurringBill CRUD ---

Future<int> insertRecurringBill(RecurringBill bill) async {
  final db = await database;
  return await db.insert('recurring_bills', bill.toMap());
}

Future<List<RecurringBill>> getRecurringBillsByHousehold(int householdId) async {
  final db = await database;
  final maps = await db.query(
    'recurring_bills',
    where: 'household_id = ? AND active = 1',
    whereArgs: [householdId],
    orderBy: 'next_due_date ASC',
  );
  return maps.map((m) => RecurringBill.fromMap(m)).toList();
}

Future<List<RecurringBill>> getDueRecurringBills(int householdId) async {
  final db = await database;
  final now = DateTime.now().toIso8601String().substring(0, 10);
  final maps = await db.query(
    'recurring_bills',
    where: 'household_id = ? AND active = 1 AND next_due_date <= ?',
    whereArgs: [householdId, now],
    orderBy: 'next_due_date ASC',
  );
  return maps.map((m) => RecurringBill.fromMap(m)).toList();
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
  await db.update('recurring_bills', {'active': 0}, where: 'id = ?', whereArgs: [id]);
}

// --- Household currency ---

Future<void> updateHouseholdCurrency(int householdId, String currency) async {
  final db = await database;
  await db.update('households', {'currency': currency}, where: 'id = ?', whereArgs: [householdId]);
}
```

**Step 5:** Update `deleteBill` to also delete `bill_item_members`:

```dart
Future<void> deleteBill(int id) async {
  final db = await database;
  // Delete junction table entries first
  final items = await db.query('bill_items', columns: ['id'], where: 'bill_id = ?', whereArgs: [id]);
  for (final item in items) {
    await db.delete('bill_item_members', where: 'bill_item_id = ?', whereArgs: [item['id']]);
  }
  await db.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
  await db.delete('bills', where: 'id = ?', whereArgs: [id]);
}
```

**Step 6:** Update `deleteHousehold` to also clean up `bill_item_members` and `recurring_bills`:

```dart
Future<void> deleteHousehold(int id) async {
  final db = await database;
  // Delete bill_item_members for all items in bills of this household
  await db.rawDelete('''
    DELETE FROM bill_item_members WHERE bill_item_id IN (
      SELECT bi.id FROM bill_items bi
      JOIN bills b ON bi.bill_id = b.id
      WHERE b.household_id = ?
    )
  ''', [id]);
  await db.delete('bill_items',
      where: 'bill_id IN (SELECT id FROM bills WHERE household_id = ?)',
      whereArgs: [id]);
  await db.delete('bills', where: 'household_id = ?', whereArgs: [id]);
  await db.delete('recurring_bills', where: 'household_id = ?', whereArgs: [id]);
  await db.delete('members', where: 'household_id = ?', whereArgs: [id]);
  await db.delete('households', where: 'id = ?', whereArgs: [id]);
}
```

**Step 7:** Update `getBillItems` to also load member IDs from junction table:

```dart
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
```

**Step 8:** Update `insertBillItems` to also insert junction table entries:

```dart
Future<void> insertBillItems(List<BillItem> items) async {
  final db = await database;
  for (final item in items) {
    final itemId = await db.insert('bill_items', item.toMap());
    if (item.sharedByMemberIds.isNotEmpty) {
      await insertBillItemMembers(itemId, item.sharedByMemberIds);
    }
  }
}
```

**Step 9:** Add import for `RecurringBill` at top of file:

```dart
import '../models/recurring_bill.dart';
```

**Step 10:** Run `flutter analyze` — expect no errors.

---

### Task 6: Update BillProvider — new balance calculation for N members

**Files:**
- Modify: `lib/providers/bill_provider.dart`

**Step 1:** Rewrite `_calculateBalances` to use junction table data:

```dart
Future<void> _calculateBalances(int householdId) async {
  final members = await _db.getMembersByHousehold(householdId);
  _memberBalances = {for (final m in members) m.id!: 0.0};

  for (final bill in _bills) {
    final payerId = bill.paidByMemberId;

    if (bill.billType == 'settlement') {
      // Settlement between payer and the "entered_by" is the one who settled
      // In a multi-member world, settlement is between the payer and one other member
      // The current logic: payer gets credit, all others get debit (divided)
      // Keep this for now — settle up is per-pair in the UI
      final otherMembers = members.where((m) => m.id != payerId).toList();
      if (otherMembers.length == 1) {
        _memberBalances[payerId] =
            (_memberBalances[payerId] ?? 0) + bill.totalAmount;
        _memberBalances[otherMembers.first.id!] =
            (_memberBalances[otherMembers.first.id!] ?? 0) - bill.totalAmount;
      }
    } else if (bill.billType == 'quick') {
      // Quick bill: split equally among all members
      final sharePerMember = bill.totalAmount / members.length;
      for (final member in members) {
        if (member.id == payerId) {
          // Payer is owed by everyone else
          _memberBalances[payerId] =
              (_memberBalances[payerId] ?? 0) + (bill.totalAmount - sharePerMember);
        } else {
          // Others owe their share
          _memberBalances[member.id!] =
              (_memberBalances[member.id!] ?? 0) - sharePerMember;
        }
      }
    } else {
      // Full bill: use junction table to determine who shares each item
      final items = await _db.getBillItems(bill.id!);

      for (final item in items) {
        if (!item.isIncluded || item.sharedByMemberIds.isEmpty) continue;

        final sharePerMember = item.price / item.sharedByMemberIds.length;

        for (final memberId in item.sharedByMemberIds) {
          if (memberId != payerId) {
            // This member owes the payer their share
            _memberBalances[payerId] =
                (_memberBalances[payerId] ?? 0) + sharePerMember;
            _memberBalances[memberId] =
                (_memberBalances[memberId] ?? 0) - sharePerMember;
          }
        }
      }
    }
  }
}
```

**Step 2:** Update `saveBill` — remove `splitPercent` references, items now use `sharedByMemberIds`:

```dart
Future<void> saveBill({
  required Bill bill,
  required List<BillItem> items,
  String? tempPhotoPath,
}) async {
  String? permanentPhotoPath;
  if (tempPhotoPath != null) {
    permanentPhotoPath = await _savePhoto(tempPhotoPath);
  }

  final billToSave = Bill(
    householdId: bill.householdId,
    enteredByMemberId: bill.enteredByMemberId,
    paidByMemberId: bill.paidByMemberId,
    billType: bill.billType,
    totalAmount: bill.totalAmount,
    photoPath: permanentPhotoPath,
    billDate: bill.billDate,
    category: bill.category,
    recurringBillId: bill.recurringBillId,
  );

  final billId = await _db.insertBill(billToSave);

  if (items.isNotEmpty) {
    final itemsWithBillId = items
        .map((item) => BillItem(
              billId: billId,
              name: item.name,
              price: item.price,
              isIncluded: item.isIncluded,
              sharedByMemberIds: item.sharedByMemberIds,
            ))
        .toList();
    await _db.insertBillItems(itemsWithBillId);
  }

  await loadBills(bill.householdId);
}
```

**Step 3:** Update `reinsertBill` similarly — use `sharedByMemberIds` instead of `splitPercent`.

**Step 4:** Update `settleUp` to accept a `receiverMemberId` for multi-member settlements:

```dart
Future<void> settleUp({
  required int householdId,
  required int payerMemberId,
  required int receiverMemberId,
  required double amount,
}) async {
  final bill = Bill(
    householdId: householdId,
    enteredByMemberId: payerMemberId,
    paidByMemberId: payerMemberId,
    billType: 'settlement',
    totalAmount: amount,
    billDate: DateTime.now(),
    category: 'other',
  );
  await _db.insertBill(bill);
  await loadBills(householdId);
}
```

**Step 5:** Run `flutter analyze`.

---

### Task 7: Update HouseholdProvider — allow N members on creation

**Files:**
- Modify: `lib/providers/household_provider.dart`

**Step 1:** `createHousehold` already accepts `List<String> memberNames` — no signature change needed. But update `HouseholdScreen` to allow adding more than 2 members (done in Task 9).

**Step 2:** Add method to add a member to an existing household:

```dart
Future<void> addMember(String name) async {
  if (_currentHousehold == null) return;
  await _db.insertMember(Member(householdId: _currentHousehold!.id!, name: name));
  _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
  notifyListeners();
}
```

**Step 3:** Add method to update household currency:

```dart
Future<void> updateCurrency(String currency) async {
  if (_currentHousehold == null) return;
  await _db.updateHouseholdCurrency(_currentHousehold!.id!, currency);
  _currentHousehold = Household(
    id: _currentHousehold!.id,
    name: _currentHousehold!.name,
    currency: currency,
    createdAt: _currentHousehold!.createdAt,
  );
  notifyListeners();
}

String get currency => _currentHousehold?.currency ?? 'TRY';
```

---

### Task 8: Update ItemRow widget — member avatar chips instead of Mine/Yours/Split

**Files:**
- Rewrite: `lib/widgets/item_row.dart`

**Step 1:** Replace entire widget. The new `ItemRow` takes a list of all household members and the currently selected member IDs:

```dart
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/member.dart';

class ItemRow extends StatelessWidget {
  final String name;
  final double price;
  final bool isIncluded;
  final List<Member> allMembers;
  final List<int> selectedMemberIds;
  final ValueChanged<List<int>> onMembersChanged;

  const ItemRow({
    super.key,
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.allMembers,
    required this.selectedMemberIds,
    required this.onMembersChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = [colorScheme.primary, colorScheme.secondary, colorScheme.tertiary,
                     AppColors.positive, AppColors.accent, AppColors.negative];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and price
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Member avatar chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allMembers.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final isSelected = selectedMemberIds.contains(member.id);
              final chipColor = colors[index % colors.length];

              return GestureDetector(
                onTap: () {
                  final updated = List<int>.from(selectedMemberIds);
                  if (isSelected) {
                    // Don't allow deselecting all members
                    if (updated.length > 1) {
                      updated.remove(member.id);
                    }
                  } else {
                    updated.add(member.id!);
                  }
                  onMembersChanged(updated);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? chipColor.withAlpha(30) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(
                      color: isSelected ? chipColor : (isDark ? AppColors.darkBorder : AppColors.border),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isSelected ? chipColor : (isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant),
                        child: Text(
                          member.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? chipColor : (isDark ? Colors.white70 : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
```

---

### Task 9: Update HouseholdScreen — allow N members on creation

**Files:**
- Modify: `lib/screens/household_screen.dart`

**Step 1:** In the create household bottom sheet / dialog, replace the fixed 2 member fields with a dynamic list:

- Start with 2 member text fields (minimum required)
- Add an "Add Member" button below that appends a new TextField
- Each additional member field (3rd+) gets a remove button
- The create button validates: name not empty, at least 2 members with non-empty names

This is a UI change only — the `createHousehold(name, memberNames)` call already accepts a list.

**Step 2:** Run `flutter analyze`.

---

### Task 10: Update ItemReviewScreen — use new ItemRow with member chips

**Files:**
- Modify: `lib/screens/item_review_screen.dart`

**Step 1:** Update `_EditableItem` class:

```dart
class _EditableItem {
  String name;
  double price;
  bool isIncluded;
  List<int> sharedByMemberIds;

  _EditableItem({
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.sharedByMemberIds,
  });
}
```

**Step 2:** Update `didChangeDependencies` to initialize `sharedByMemberIds` with all member IDs (default: everyone shares):

```dart
final allMemberIds = context.read<HouseholdProvider>().members.map((m) => m.id!).toList();
_items = parsed.items
    .map((item) => _EditableItem(
          name: item.name,
          price: item.price,
          isIncluded: true,
          sharedByMemberIds: List.from(allMemberIds),
        ))
    .toList();
```

**Step 3:** Update the `ItemRow` usage in the build method to pass `allMembers` and `selectedMemberIds` instead of `splitPercent`.

**Step 4:** Update `_splitAmount` getter — now calculates what each non-payer member owes:

```dart
Map<int, double> get _memberOwes {
  final result = <int, double>{};
  for (final item in _items) {
    if (item.isIncluded && item.sharedByMemberIds.isNotEmpty) {
      final share = item.price / item.sharedByMemberIds.length;
      for (final memberId in item.sharedByMemberIds) {
        if (memberId != _paidByMemberId) {
          result[memberId] = (result[memberId] ?? 0) + share;
        }
      }
    }
  }
  return result;
}
```

**Step 5:** Update bottom summary to show per-member owes instead of single "other owes" line.

**Step 6:** Update `_saveBill` to create `BillItem` objects with `sharedByMemberIds`.

**Step 7:** Update `_addManualItem` to default `sharedByMemberIds` to all members.

---

### Task 11: Update QuickReviewScreen — N-way split

**Files:**
- Modify: `lib/screens/quick_review_screen.dart`

**Step 1:** Update split preview to show each member's share (total / N members).

**Step 2:** Update the "owes" text to show per-member amounts.

**Step 3:** The payer dropdown already shows all members — no change needed.

---

### Task 12: Update BalanceCard — per-member balances

**Files:**
- Modify: `lib/widgets/balance_card.dart`

**Step 1:** Change props from single `balanceAmount` to `Map<int, double> memberBalances` and `Map<int, String> memberNames`. Also keep `currentMemberId`.

**Step 2:** Display a row for each member (except current) showing their balance. Each row has its own Settle Up button.

**Step 3:** If all balances are zero, show "All settled up!" state.

---

### Task 13: Update HomeScreen — per-member settle up

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1:** Update BalanceCard usage to pass the new props.

**Step 2:** Update `_confirmSettleUp` to accept a specific `otherMemberId` (not just assume one other member).

**Step 3:** Update settle up call to pass `receiverMemberId`.

---

### Task 14: Update BillDetailScreen — show member chips

**Files:**
- Modify: `lib/screens/bill_detail_screen.dart`

**Step 1:** For full bills, show which members share each item (display member initials as small chips next to each item row).

**Step 2:** For quick bills, show "Split equally among all members".

---

### Task 15: Phase 1 verification

**Step 1:** Run `flutter analyze` — expect 0 errors, 0 warnings.

**Step 2:** Run `flutter build apk --debug` — expect successful build.

**Step 3:** Manual testing:
- Create new household with 3 members
- Add a full bill, assign different members to different items
- Verify balances calculate correctly
- Settle up between specific pairs
- Create a quick bill, verify equal N-way split

**Step 4:** Commit:
```bash
git add -A
git commit -m "feat: multi-member household support with N-way item splitting"
```

---

## Phase 2 — New Features

### Task 16: Currency support — add to constants and UI

**Files:**
- Modify: `lib/constants.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: all screens that display amounts (grep for `TL` and `toStringAsFixed`)

**Step 1:** Add currency data to `constants.dart`:

```dart
class AppCurrency {
  final String code;   // 'TRY'
  final String symbol; // '₺'
  final String name;   // 'Turkish Lira'

  const AppCurrency(this.code, this.symbol, this.name);

  static const list = [
    AppCurrency('TRY', '₺', 'Turkish Lira'),
    AppCurrency('USD', '\$', 'US Dollar'),
    AppCurrency('EUR', '€', 'Euro'),
    AppCurrency('GBP', '£', 'British Pound'),
    AppCurrency('SAR', '﷼', 'Saudi Riyal'),
    AppCurrency('AED', 'د.إ', 'UAE Dirham'),
    AppCurrency('JPY', '¥', 'Japanese Yen'),
    AppCurrency('KRW', '₩', 'South Korean Won'),
  ];

  static AppCurrency getByCode(String code) =>
      list.firstWhere((c) => c.code == code, orElse: () => list.first);
}
```

**Step 2:** Create a helper method in `HouseholdProvider` (or a utility):

```dart
String formatAmount(double amount) {
  final curr = AppCurrency.getByCode(currency);
  return '${amount.toStringAsFixed(2)} ${curr.symbol}';
}
```

**Step 3:** Replace all hardcoded `'TL'` and `toStringAsFixed(2) TL` with the currency-aware formatter. Grep for `TL` across all screen and widget files.

**Step 4:** Add currency dropdown to Settings screen under GENERAL section.

**Step 5:** Commit: `git commit -m "feat: multi-currency support per household"`

---

### Task 17: Bottom navigation — Bills | Insights tabs

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1:** Wrap current HomeScreen body in a `BottomNavigationBar` with 2 tabs:
- Tab 0: Bills (current home content) — icon: `Icons.receipt_long_rounded`
- Tab 1: Insights — icon: `Icons.insights_rounded`

**Step 2:** Use `IndexedStack` or simple conditional to switch between the two tab views, preserving scroll state.

**Step 3:** Tab 1 content is a placeholder `Center(child: Text('Insights coming soon'))` for now — built in Task 18.

**Step 4:** Commit: `git commit -m "feat: add bottom nav with Bills and Insights tabs"`

---

### Task 18: Insights tab — category and member spending bars

**Files:**
- Create: `lib/screens/insights_screen.dart`
- Modify: `lib/providers/bill_provider.dart` (add insights data methods)
- Modify: `lib/screens/home_screen.dart` (replace placeholder with InsightsScreen)

**Step 1:** Add insights data methods to `BillProvider`:

```dart
class MonthlyInsights {
  final String monthLabel;
  final int year;
  final int month;
  final int billCount;
  final double totalSpent;
  final Map<String, double> categorySpend;   // categoryId -> total
  final Map<int, double> memberSpend;         // memberId -> total paid
}
```

- `getInsightsForMonth(int householdId, int year, int month)` — filters bills, aggregates by category and member.

**Step 2:** Create `InsightsScreen` as a StatefulWidget:

- Month selector at top with left/right arrows and month label
- "Total Spent" card with amount and bill count
- "By Category" section with horizontal colored bars. Each bar: category icon + label + proportional width bar + percentage + amount
- "By Member" section with horizontal colored bars showing each member's spend
- Export button in top right → bottom sheet with Share/CSV/PDF options

**Step 3:** Each bar is a simple `Container` with proportional `width` (as fraction of max value), colored with the category/member color, inside a `Row`. No charting library needed.

**Step 4:** Hook InsightsScreen into HomeScreen tab 1.

**Step 5:** Commit: `git commit -m "feat: add insights tab with category and member spending charts"`

---

### Task 19: Recurring bills — model, creation, and banner

**Files:**
- Create: `lib/providers/recurring_bill_provider.dart`
- Modify: `lib/screens/home_screen.dart` (add banner)
- Modify: `lib/screens/bill_detail_screen.dart` (add "Make Recurring" action)

**Step 1:** Create `RecurringBillProvider`:

```dart
class RecurringBillProvider extends ChangeNotifier {
  List<RecurringBill> _dueBills = [];
  List<RecurringBill> get dueBills => _dueBills;

  Future<void> loadDueBills(int householdId) async { ... }
  Future<void> confirmBill(RecurringBill bill, BillProvider billProvider) async { ... }
  Future<void> dismissBill(RecurringBill bill) async { ... }
  Future<void> createRecurring({...}) async { ... }
}
```

**Step 2:** Register provider in `main.dart`.

**Step 3:** In HomeScreen Bills tab, add a banner section above the balance card. For each due recurring bill, show a card with: title, amount, [Confirm] [Dismiss] buttons.

- Confirm: creates a bill with pre-filled data, advances `next_due_date`
- Dismiss: advances `next_due_date` (skip this occurrence)

**Step 4:** In BillDetailScreen, add a "Make Recurring" action button (or menu item). Opens a bottom sheet where user picks frequency (weekly/monthly/yearly). Creates a `RecurringBill` entry linked to this bill's category, amount, and payer.

**Step 5:** Commit: `git commit -m "feat: recurring bills with due date banner and one-tap confirm"`

---

### Task 20: Settings reorganization

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Step 1:** Reorganize into 4 sections:
- **GENERAL**: Currency dropdown + Dark mode toggle
- **RECEIPT SCANNING**: API key input with status dot
- **SECURITY**: PIN management
- **ABOUT**: App name + version

**Step 2:** Currency dropdown reads from and writes to `HouseholdProvider.currency` / `HouseholdProvider.updateCurrency()`.

**Step 3:** Commit: `git commit -m "feat: reorganize settings with currency selector"`

---

### Task 21: Phase 2 verification

**Step 1:** Run `flutter analyze` — expect 0 errors.

**Step 2:** Run `flutter build apk --debug`.

**Step 3:** Manual testing:
- Change currency to USD, verify symbol updates throughout app
- Navigate between Bills and Insights tabs
- Check insights shows correct category/member breakdowns
- Create a recurring bill, verify banner appears when due
- Verify settings reorganization looks clean

**Step 4:** Commit all remaining changes and push:
```bash
git push origin master
```

---

## Phase 3 — Export & Polish (separate plan document)

Tasks 22-25: Share sheet export, CSV export, PDF export, OCR feedback improvement. To be planned after Phase 2 is complete.

## Phase 4 — Cloud Sync (separate plan document)

Tasks 26-28: Supabase setup, sync engine, auth. To be planned after Phase 3 is complete.
