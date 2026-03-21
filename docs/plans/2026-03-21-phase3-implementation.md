# Phase 3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close UX gaps — bill filtering, member edit/delete, CSV export, undo deletion, recurring bill management.

**Architecture:** In-memory filtering via BillProvider (no query changes), soft-delete members via DB migration v6, CSV export using StringBuffer + share_plus, undo via Navigator result passing, recurring management via new screen.

**Tech Stack:** Flutter, Provider, sqflite, share_plus (new dep), path_provider

---

## Task 1: BillFilter Model

**Files:**
- Create: `lib/models/bill_filter.dart`

**Step 1: Create the BillFilter class**

```dart
class BillFilter {
  final String? category;
  final int? memberId;
  final bool filterByPaidBy; // true = "paid by", false = "shared with"
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? datePresetLabel;

  const BillFilter({
    this.category,
    this.memberId,
    this.filterByPaidBy = true,
    this.dateFrom,
    this.dateTo,
    this.datePresetLabel,
  });

  BillFilter copyWith({
    String? category,
    int? memberId,
    bool? filterByPaidBy,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? datePresetLabel,
  }) {
    return BillFilter(
      category: category ?? this.category,
      memberId: memberId ?? this.memberId,
      filterByPaidBy: filterByPaidBy ?? this.filterByPaidBy,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      datePresetLabel: datePresetLabel ?? this.datePresetLabel,
    );
  }

  bool get hasActiveFilters =>
      category != null || memberId != null || dateFrom != null || dateTo != null;

  int get activeFilterCount {
    int count = 0;
    if (category != null) count++;
    if (memberId != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/bill_filter.dart
git commit -m "feat: add BillFilter model for in-memory bill filtering"
```

---

## Task 2: Add Filtering to BillProvider

**Files:**
- Modify: `lib/providers/bill_provider.dart`

**Step 1: Add filter state and filteredBills getter**

After the `_balanceCacheKey` field (line 49), add:

```dart
BillFilter? _activeFilter;
BillFilter? get activeFilter => _activeFilter;
```

After the `monthlySummary` getter (line 53), add:

```dart
List<Bill> get filteredBills {
  if (_activeFilter == null || !_activeFilter!.hasActiveFilters) return _bills;
  return _bills.where((bill) => _matchesFilter(bill)).toList();
}

bool _matchesFilter(Bill bill) {
  final f = _activeFilter!;
  if (f.category != null && bill.category != f.category) return false;
  if (f.dateFrom != null && bill.billDate.isBefore(f.dateFrom!)) return false;
  if (f.dateTo != null && bill.billDate.isAfter(f.dateTo!)) return false;
  // Member filtering is async (needs items for "shared with") — handled in step 2
  return true;
}
```

**Step 2: Add setFilter and clearFilter methods**

After the `reinsertBill` method (line 273), add:

```dart
void setFilter(BillFilter? filter) {
  _activeFilter = filter;
  notifyListeners();
}

void clearFilter() {
  _activeFilter = null;
  notifyListeners();
}
```

**Step 3: Handle member filtering**

The "shared with" filter requires checking bill items (async). Since we filter in memory and the bill list is small, preload item member IDs into a cache when filter is set.

Add a field:

```dart
Map<int, List<int>> _billSharedMemberIds = {};
```

Add a method to populate it:

```dart
Future<void> _loadSharedMemberIds() async {
  _billSharedMemberIds = {};
  for (final bill in _bills) {
    if (bill.billType == 'full') {
      final items = await _db.getBillItems(bill.id!);
      final memberIds = <int>{};
      for (final item in items) {
        memberIds.addAll(item.sharedByMemberIds);
      }
      _billSharedMemberIds[bill.id!] = memberIds.toList();
    } else {
      // Quick bills are shared by all members — will be populated from household members
      _billSharedMemberIds[bill.id!] = [];
    }
  }
}
```

Update `setFilter` to call `_loadSharedMemberIds()` when member filter is set with "shared with" mode:

```dart
Future<void> setFilter(BillFilter? filter) async {
  _activeFilter = filter;
  if (filter?.memberId != null && !(filter?.filterByPaidBy ?? true)) {
    await _loadSharedMemberIds();
  }
  notifyListeners();
}
```

Update `_matchesFilter` to handle member:

```dart
bool _matchesFilter(Bill bill) {
  final f = _activeFilter!;
  if (f.category != null && bill.category != f.category) return false;
  if (f.dateFrom != null && bill.billDate.isBefore(f.dateFrom!)) return false;
  if (f.dateTo != null && bill.billDate.isAfter(
      DateTime(f.dateTo!.year, f.dateTo!.month, f.dateTo!.day, 23, 59, 59))) return false;
  if (f.memberId != null) {
    if (f.filterByPaidBy) {
      if (bill.paidByMemberId != f.memberId) return false;
    } else {
      final sharedIds = _billSharedMemberIds[bill.id!] ?? [];
      if (!sharedIds.contains(f.memberId)) return false;
    }
  }
  return true;
}
```

**Step 4: Commit**

```bash
git add lib/providers/bill_provider.dart
git commit -m "feat: add filter state and filteredBills getter to BillProvider"
```

---

## Task 3: Filter Bottom Sheet UI

**Files:**
- Create: `lib/widgets/filter_bottom_sheet.dart`

**Step 1: Create the filter bottom sheet widget**

Build a `StatefulWidget` that shows inside `showModalBottomSheet`. Sections:

1. **Category section** — `Wrap` of `FilterChip` widgets using `BillCategories.list`
2. **Member section** — `DropdownButtonFormField` for member selection + `SegmentedButton` for paid-by/shared-with toggle
3. **Date section** — Row of preset `ChoiceChip` widgets ("This month", "Last 30 days", "Last 3 months") + "Custom" button that opens `showDateRangePicker`
4. **Action row** — "Clear all" TextButton + "Apply" FilledButton

The widget takes:
- `BillFilter? currentFilter` — to pre-populate selections
- `List<Member> members` — for the member dropdown
- `ValueChanged<BillFilter?> onApply` — callback with new filter

Full implementation is ~200 lines of standard Flutter form widgets — follow existing app patterns:
- Use `isDark` checks throughout
- Use `AppColors`, `AppRadius`, `AppSpacing` from constants
- Use `BillCategories.list` for category chips
- Spring curve for bottom sheet: `showModalBottomSheet` with `AnimationStyle(curve: Curves.easeOutCubic)`

**Step 2: Commit**

```bash
git add lib/widgets/filter_bottom_sheet.dart
git commit -m "feat: add filter bottom sheet widget with category, member, date sections"
```

---

## Task 4: Filter Chips Bar and HomeScreen Integration

**Files:**
- Create: `lib/widgets/filter_chips_bar.dart`
- Modify: `lib/screens/home_screen.dart`

**Step 1: Create FilterChipsBar widget**

A `StatelessWidget` that displays active filters as dismissible chips in a horizontal `ListView`. Takes:
- `BillFilter filter`
- `List<Member> members` — to resolve member names
- `ValueChanged<BillFilter?> onFilterChanged` — called when a chip is removed

Each chip: `Chip` with `onDeleted` callback that returns a new `BillFilter` with that field nulled out.

**Step 2: Add filter icon to HomeScreen app bar**

In `home_screen.dart`, in the `actions` list (line 60-81), add a filter icon **before** the settings icon:

```dart
IconButton(
  icon: Stack(
    children: [
      Icon(Icons.filter_list_rounded,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      if (billProvider.activeFilter?.hasActiveFilters ?? false)
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  ),
  onPressed: () => _showFilterSheet(context),
  tooltip: 'Filter',
),
```

**Step 3: Add export icon next to filter**

```dart
IconButton(
  icon: Icon(Icons.file_download_outlined,
      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
  onPressed: () => _exportBills(context),
  tooltip: 'Export',
),
```

**Step 4: Add _showFilterSheet method to _HomeScreenState**

```dart
void _showFilterSheet(BuildContext context) {
  final billProvider = context.read<BillProvider>();
  final members = context.read<HouseholdProvider>().members;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FilterBottomSheet(
      currentFilter: billProvider.activeFilter,
      members: members,
      onApply: (filter) {
        billProvider.setFilter(filter);
        Navigator.pop(context);
      },
    ),
  );
}
```

**Step 5: Insert FilterChipsBar into bill list**

In `_buildBillsTab`, between the balance card section and the bill list, add:

```dart
if (billProvider.activeFilter?.hasActiveFilters ?? false)
  FilterChipsBar(
    filter: billProvider.activeFilter!,
    members: members,
    onFilterChanged: (f) => billProvider.setFilter(f),
  ),
```

**Step 6: Replace `billProvider.bills` with `billProvider.filteredBills`**

In the bill list section (line 577), change:

```dart
// Before:
...billProvider.bills.map((bill) {
// After:
...billProvider.filteredBills.map((bill) {
```

Also update the empty state check to account for "no results" vs "no bills":

```dart
if (billProvider.filteredBills.isEmpty && billProvider.bills.isNotEmpty)
  // Show "No bills match filters" with a "Clear filters" button
else if (billProvider.bills.isEmpty)
  // Show existing "No bills yet" empty state
```

**Step 7: Commit**

```bash
git add lib/widgets/filter_chips_bar.dart lib/screens/home_screen.dart
git commit -m "feat: integrate filter UI into HomeScreen with chips bar and bottom sheet"
```

---

## Task 5: Member Soft Delete — Database Migration v6

**Files:**
- Modify: `lib/models/member.dart`
- Modify: `lib/database/database_helper.dart`

**Step 1: Add isActive field to Member model**

In `lib/models/member.dart`, add:

```dart
class Member {
  final int? id;
  final int householdId;
  final String name;
  final String? pin;
  final bool isActive;

  Member({
    this.id,
    required this.householdId,
    required this.name,
    this.pin,
    this.isActive = true,
  });
```

Update `toMap()`:
```dart
'is_active': isActive ? 1 : 0,
```

Update `fromMap()`:
```dart
isActive: (map['is_active'] as int?) != 0, // default true for pre-v6 rows
```

Update `==` and `hashCode` — no change needed (still based on `id`).

**Step 2: Database migration v6**

In `database_helper.dart`, change version from `5` to `6` (line 26).

In `_onCreate`, add `is_active` to members table:

```sql
is_active INTEGER NOT NULL DEFAULT 1,
```

In `_onUpgrade`, add:

```dart
if (oldVersion < 6) {
  await db.execute("ALTER TABLE members ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1");
}
```

**Step 3: Update getMembersByHousehold to filter active only**

```dart
Future<List<Member>> getMembersByHousehold(int householdId) async {
  final db = await database;
  final maps = await db.query(
    'members',
    where: 'household_id = ? AND is_active = 1',
    whereArgs: [householdId],
  );
  return maps.map((map) => Member.fromMap(map)).toList();
}
```

Add a new method for all members (including inactive):

```dart
Future<List<Member>> getAllMembersByHousehold(int householdId) async {
  final db = await database;
  final maps = await db.query(
    'members',
    where: 'household_id = ?',
    whereArgs: [householdId],
  );
  return maps.map((map) => Member.fromMap(map)).toList();
}
```

**Step 4: Add rename and soft-delete DB methods**

```dart
Future<void> updateMemberName(int memberId, String name) async {
  final db = await database;
  await db.update('members', {'name': name}, where: 'id = ?', whereArgs: [memberId]);
}

Future<void> setMemberActive(int memberId, bool active) async {
  final db = await database;
  await db.update('members', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [memberId]);
}
```

**Step 5: Commit**

```bash
git add lib/models/member.dart lib/database/database_helper.dart
git commit -m "feat: member soft-delete — DB migration v6, isActive field, rename support"
```

---

## Task 6: Member Edit/Delete — Provider and UI

**Files:**
- Modify: `lib/providers/household_provider.dart`
- Modify: `lib/screens/member_select_screen.dart`
- Modify: `lib/screens/settings_screen.dart`

**Step 1: Add renameMember and softDeleteMember to HouseholdProvider**

```dart
Future<void> renameMember(int memberId, String newName) async {
  if (_currentHousehold == null) return;
  final trimmed = newName.trim();
  if (trimmed.isEmpty || trimmed.length > 50) return;
  if (_members.any((m) => m.id != memberId && m.name.toLowerCase() == trimmed.toLowerCase())) return;
  await _db.updateMemberName(memberId, trimmed);
  _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
  notifyListeners();
}

Future<bool> softDeleteMember(int memberId) async {
  if (_currentHousehold == null) return false;
  // Block if last active member
  final activeCount = _members.where((m) => m.isActive).length;
  if (activeCount <= 1) return false;
  await _db.setMemberActive(memberId, false);
  if (_currentMember?.id == memberId) {
    _currentMember = null;
  }
  _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
  notifyListeners();
  return true;
}
```

**Step 2: Add long-press menu to MemberSelectScreen**

Add a `_showMemberOptions` method that shows a bottom sheet with "Rename" and "Remove from household". Wire it to `onLongPress` on member tiles.

- Rename: shows a `TextFormField` dialog, calls `householdProvider.renameMember()`
- Remove: shows confirmation dialog, calls `householdProvider.softDeleteMember()`

**Step 3: Add same long-press menu to SettingsScreen member list**

Same pattern as MemberSelectScreen — member tiles in the PIN management section get `onLongPress` with the same options sheet.

**Step 4: Commit**

```bash
git add lib/providers/household_provider.dart lib/screens/member_select_screen.dart lib/screens/settings_screen.dart
git commit -m "feat: member rename and soft-delete with long-press menu"
```

---

## Task 7: CSV Export

**Files:**
- Modify: `lib/providers/bill_provider.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/insights_screen.dart`
- Modify: `pubspec.yaml`

**Step 1: Add share_plus dependency**

In `pubspec.yaml`, add under `dependencies`:

```yaml
share_plus: ^11.0.0
```

Run: `flutter pub get`

**Step 2: Add export method to BillProvider**

```dart
Future<String> exportFilteredBillsCsv(List<Member> allMembers) async {
  final bills = filteredBills;
  final buf = StringBuffer();
  buf.writeln('Date,Bill Type,Category,Paid By,Total,Items,Shared With');

  for (final bill in bills) {
    final payer = allMembers.where((m) => m.id == bill.paidByMemberId).firstOrNull;
    final payerName = payer?.name ?? 'Unknown';
    final date = '${bill.billDate.year}-${bill.billDate.month.toString().padLeft(2, '0')}-${bill.billDate.day.toString().padLeft(2, '0')}';

    String items = '';
    String sharedWith = '';
    if (bill.billType == 'full') {
      final billItems = await _db.getBillItems(bill.id!);
      items = billItems.map((i) => i.name).join(';');
      final memberIds = <int>{};
      for (final item in billItems) {
        memberIds.addAll(item.sharedByMemberIds);
      }
      sharedWith = memberIds
          .map((id) => allMembers.where((m) => m.id == id).firstOrNull?.name ?? 'Unknown')
          .join(';');
    } else {
      sharedWith = allMembers.map((m) => m.name).join(';');
    }

    buf.writeln('"$date","${bill.billType}","${bill.category}","$payerName",${bill.totalAmount},"$items","$sharedWith"');
  }

  final dir = await getTemporaryDirectory();
  final now = DateTime.now();
  final fileName = 'billsplit_export_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(buf.toString());
  return file.path;
}
```

Add import at top: `import 'dart:io';` (already exists), `import 'package:path_provider/path_provider.dart';` (already exists).

**Step 3: Add _exportBills to HomeScreen**

```dart
Future<void> _exportBills(BuildContext context) async {
  final billProvider = context.read<BillProvider>();
  final allMembers = await DatabaseHelper.instance.getAllMembersByHousehold(
    context.read<HouseholdProvider>().currentHousehold!.id!,
  );
  final path = await billProvider.exportFilteredBillsCsv(allMembers);
  await Share.shareXFiles([XFile(path)], subject: 'Bill Split Export');
}
```

Add import: `import 'package:share_plus/share_plus.dart';`

**Step 4: Replace "Export coming soon" in InsightsScreen**

In `lib/screens/insights_screen.dart` (line 89-98), replace the snackbar `onPressed` with the same export logic:

```dart
onPressed: () async {
  final billProvider = context.read<BillProvider>();
  final allMembers = await DatabaseHelper.instance.getAllMembersByHousehold(
    context.read<HouseholdProvider>().currentHousehold!.id!,
  );
  final path = await billProvider.exportFilteredBillsCsv(allMembers);
  await Share.shareXFiles([XFile(path)], subject: 'Bill Split Export');
},
```

Add imports: `import 'package:share_plus/share_plus.dart';`, `import '../database/database_helper.dart';`

**Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/providers/bill_provider.dart lib/screens/home_screen.dart lib/screens/insights_screen.dart
git commit -m "feat: CSV export of filtered bills via share sheet"
```

---

## Task 8: Undo Bill Deletion in Detail Screen

**Files:**
- Modify: `lib/screens/bill_detail_screen.dart`
- Modify: `lib/screens/home_screen.dart`

**Step 1: Change BillDetailScreen delete to pass result**

In `bill_detail_screen.dart`, modify `_confirmDelete` (line 742-749):

```dart
onPressed: () async {
  Navigator.pop(dialogContext); // close dialog

  // Capture bill and items before deletion
  final deletedBill = bill;
  final deletedItems = bill.billType == 'full'
      ? await context.read<BillProvider>().getBillItems(bill.id!)
      : <BillItem>[];

  if (!context.mounted) return;
  await context.read<BillProvider>().deleteBill(bill.id!, bill.householdId);

  if (context.mounted) {
    Navigator.pop(context, {
      'deleted': true,
      'bill': deletedBill,
      'items': deletedItems,
    });
  }
},
```

Add import at top: `import '../models/bill_item.dart';` (if not already present).

**Step 2: Handle result in HomeScreen**

Where `BillDetailScreen` is navigated to (find the `Navigator.pushNamed(context, '/bill-detail', ...)` call), change to await the result:

```dart
final result = await Navigator.pushNamed(context, '/bill-detail', arguments: bill);
if (result is Map && result['deleted'] == true && context.mounted) {
  final deletedBill = result['bill'] as Bill;
  final deletedItems = result['items'] as List<BillItem>;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Bill deleted'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          context.read<BillProvider>().reinsertBill(deletedBill, deletedItems);
        },
      ),
    ),
  );
}
```

**Step 3: Commit**

```bash
git add lib/screens/bill_detail_screen.dart lib/screens/home_screen.dart
git commit -m "feat: undo bill deletion from detail screen via snackbar"
```

---

## Task 9: Recurring Bill Management — Database and Provider

**Files:**
- Modify: `lib/database/database_helper.dart`
- Modify: `lib/providers/recurring_bill_provider.dart`

**Step 1: Add DB methods**

In `database_helper.dart`, add after `deactivateRecurringBill`:

```dart
Future<void> reactivateRecurringBill(int id) async {
  final db = await database;
  await db.update('recurring_bills', {'active': 1}, where: 'id = ?', whereArgs: [id]);
}

Future<void> updateRecurringBill(RecurringBill bill) async {
  final db = await database;
  await db.update('recurring_bills', bill.toMap(), where: 'id = ?', whereArgs: [bill.id]);
}

Future<void> deleteRecurringBillPermanently(int id) async {
  final db = await database;
  await db.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
}
```

**Step 2: Add provider methods**

In `recurring_bill_provider.dart`, add:

```dart
List<RecurringBill> _allRecurringBills = [];
List<RecurringBill> get allRecurringBills => _allRecurringBills;

Future<void> loadAllRecurringBills(int householdId) async {
  _allRecurringBills = await _db.getRecurringBillsByHousehold(householdId);
  notifyListeners();
}

Future<void> toggleActive(int id, bool active, int householdId) async {
  if (active) {
    await _db.reactivateRecurringBill(id);
  } else {
    await _db.deactivateRecurringBill(id);
  }
  await loadAllRecurringBills(householdId);
  await loadDueBills(householdId);
}

Future<void> updateRecurring(RecurringBill bill, int householdId) async {
  await _db.updateRecurringBill(bill);
  await loadAllRecurringBills(householdId);
  await loadDueBills(householdId);
}

Future<void> deleteRecurringPermanently(int id, int householdId) async {
  await _db.deleteRecurringBillPermanently(id);
  await loadAllRecurringBills(householdId);
  await loadDueBills(householdId);
}
```

**Step 3: Commit**

```bash
git add lib/database/database_helper.dart lib/providers/recurring_bill_provider.dart
git commit -m "feat: recurring bill CRUD — reactivate, update, hard delete"
```

---

## Task 10: Recurring Bill Management Screen

**Files:**
- Create: `lib/screens/recurring_bills_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart`

**Step 1: Create RecurringBillsScreen**

A `StatefulWidget` that:
- Calls `recurringBillProvider.loadAllRecurringBills(householdId)` in `didChangeDependencies`
- Shows a `ListView` of all recurring bills (active + inactive)
- Each row: title, amount (formatted), frequency badge, next due date, category icon
- `Switch` widget on each row to toggle active/inactive
- `Dismissible` with swipe-to-delete (shows confirmation dialog, calls `deleteRecurringPermanently`)
- Tap opens an edit bottom sheet with: title, amount, frequency dropdown, category chips, paid-by member dropdown
- Edit bottom sheet has "Save" button that calls `updateRecurring`
- Empty state: "No recurring bills" with icon

Follow existing app patterns: dark mode checks, AppColors, AppRadius, same card styling as BillListTile.

**Step 2: Add route in main.dart**

In `main.dart`, add import and route:

```dart
import 'screens/recurring_bills_screen.dart';
```

In the routes map:
```dart
'/recurring-bills': (context) => const RecurringBillsScreen(),
```

**Step 3: Add "Manage Recurring Bills" item to SettingsScreen**

In `settings_screen.dart`, add a new list tile in an appropriate section:

```dart
ListTile(
  leading: Icon(Icons.repeat_rounded, color: AppColors.primary),
  title: Text('Manage Recurring Bills'),
  trailing: Icon(Icons.chevron_right_rounded),
  onTap: () => Navigator.pushNamed(context, '/recurring-bills'),
),
```

**Step 4: Commit**

```bash
git add lib/screens/recurring_bills_screen.dart lib/screens/settings_screen.dart lib/main.dart
git commit -m "feat: recurring bill management screen with edit, toggle, delete"
```

---

## Task 11: Final Integration and Polish

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Update "no bills" empty state for filtered view**

When filters are active but no bills match, show a different empty state:

```dart
if (billProvider.filteredBills.isEmpty && billProvider.bills.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.filter_list_off_rounded, size: 48,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('No bills match filters',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => billProvider.clearFilter(),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    ),
  )
```

**Step 2: Verify filter chips animate**

Wrap the `FilterChipsBar` in an `AnimatedSwitcher` for smooth appear/disappear:

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: (billProvider.activeFilter?.hasActiveFilters ?? false)
      ? FilterChipsBar(key: const ValueKey('chips'), ...)
      : const SizedBox.shrink(key: ValueKey('empty')),
),
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

Fix any warnings.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: Phase 3 complete — filtering, member mgmt, export, undo, recurring"
```
