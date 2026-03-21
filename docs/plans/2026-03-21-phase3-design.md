# Phase 3 Design — Close the Gaps

**Date:** 2026-03-21
**Scope:** 5 features that complete the existing UX before adding new systems.
**Order:** Filtering → Member mgmt → Export → Undo → Recurring management

---

## 1. Bill Filtering

### Data Model

New in-memory-only class (not persisted):

```dart
class BillFilter {
  final String? category;       // null = all categories
  final int? memberId;          // null = all members
  final bool filterByPaidBy;    // true = "paid by", false = "shared with"
  final DateTime? dateFrom;     // null = no lower bound
  final DateTime? dateTo;       // null = no upper bound
  final String? datePresetLabel; // "Last 30 days", etc.
}
```

### Provider

`BillProvider` gains:
- `BillFilter? activeFilter` field
- `List<Bill> get filteredBills` — applies filter to loaded bills in memory
- `void setFilter(BillFilter?)` — sets filter and calls `notifyListeners()`
- `void clearFilter()` — resets to null

No database query changes — bills are already loaded into memory.

### UI

- **Filter icon** in HomeScreen app bar (Bills tab only), shows badge dot when filters active.
- **Bottom sheet** with three sections:
  - Category: `Wrap` of `FilterChip` widgets (9 categories)
  - Member: dropdown + "paid by" / "shared with" toggle
  - Date range: preset buttons ("This month", "Last 30 days", "Last 3 months") + custom date range picker
  - "Apply" and "Clear all" buttons at bottom
- **Active filter chips**: horizontal `ListView` of dismissible `Chip` widgets between tab bar and bill list
  - Each chip shows value (e.g., "Groceries", "Ahmed (paid by)", "Last 30 days")
  - X button removes that single filter
  - Staggered slide-up animation on appear, `AnimatedList` removal

### Design Inspiration

Adapted from 21st.dev Tag Selector and Modal/Dialog patterns:
- Spring-curve bottom sheet animation
- Staggered chip entry animation
- Filter chips with subtle border + filled background when active

---

## 2. Member Edit/Delete (Soft Delete)

### Database

Migration v6: add `is_active INTEGER NOT NULL DEFAULT 1` to `members` table.

### Provider

`HouseholdProvider` gains:
- `renameMember(int memberId, String newName)` — same validation as addMember (empty, >50 chars, case-insensitive duplicate check)
- `softDeleteMember(int memberId)` — sets `is_active = 0`. Blocks if last active member.
- `reactivateMember(int memberId)` — sets `is_active = 1` (for future use)
- Existing member queries filter by `is_active = 1` for all active-use contexts (dropdowns, assignment, filters)
- Historical bill displays query by ID, ignoring active status

### UI

- Long-press a member in `MemberSelectScreen` or `SettingsScreen` → bottom sheet:
  - "Rename" — inline text field with existing validation
  - "Remove from household" — confirmation dialog explaining soft delete behavior
- Removed members disappear from: member select, "paid by" dropdowns, item assignment, filter member list
- Removed members still appear in: historical bill details, balance calculations, export data

---

## 3. Data Export (CSV)

### Format

Exports the currently filtered bill list. Columns:

```
Date, Bill Type, Category, Paid By, Total, Items, Shared With
```

- Items are semicolon-separated within the field
- Filename: `billsplit_export_YYYY-MM-DD.csv`

### Implementation

- No new dependencies. `StringBuffer` builds CSV, `path_provider` writes to temp dir, Android share sheet sends the file.
- Uses `share_plus` package if not already present, otherwise native share intent.

### UI

Two export entry points:
- **Insights screen** — replaces "Export coming soon" snackbar
- **Home screen** — export icon next to filter icon (exports filtered view)

Both trigger the same export logic.

---

## 4. Undo Bill Deletion (Detail Screen)

### Current State

- HomeScreen: swipe-to-dismiss + snackbar undo already works via `reinsertBill()`
- BillDetailScreen: delete is permanent, no undo

### Fix

- BillDetailScreen captures bill + items before deletion
- After delete, pops with result: `Navigator.pop(context, 'deleted')`
- HomeScreen receives the result and shows undo snackbar (it already has the bill data in its list)
- No new files or methods needed

---

## 5. Recurring Bill Management

### Database

- Add `updateRecurringBill(RecurringBill)` — updates title, amount, frequency, category, paidByMemberId
- Add `reactivateRecurringBill(int id)` — sets `active = 1` (inverse of existing deactivate)

### Provider

`RecurringBillProvider` gains:
- `updateRecurringBill(RecurringBill)` — validates and persists changes
- `reactivateRecurringBill(int id)` — reactivates paused bill
- `getAllRecurringBills(int householdId)` — returns all (active + inactive) for management screen
- `deleteRecurringBill(int id)` — hard delete with confirmation

### UI

New screen accessible from **Settings → "Manage Recurring Bills"**:
- List of all recurring bills (active + inactive)
- Each row: title, amount, frequency, next due date, category icon
- Toggle switch to pause/activate
- Swipe to delete (with confirmation dialog)
- Tap to edit (bottom sheet: title, amount, frequency, category, paid-by member)

---

## Files Affected (Estimated)

| Feature | New Files | Modified Files |
|---------|-----------|----------------|
| Filtering | `lib/models/bill_filter.dart` | `bill_provider.dart`, `home_screen.dart`, `constants.dart` |
| Member mgmt | — | `database_helper.dart`, `household_provider.dart`, `member_select_screen.dart`, `settings_screen.dart`, `member.dart` |
| Export | — | `home_screen.dart`, `insights_screen.dart`, `bill_provider.dart`, `pubspec.yaml` (share_plus) |
| Undo | — | `bill_detail_screen.dart`, `home_screen.dart` |
| Recurring mgmt | `lib/screens/recurring_bills_screen.dart` | `database_helper.dart`, `recurring_bill_provider.dart`, `settings_screen.dart`, `main.dart` |
