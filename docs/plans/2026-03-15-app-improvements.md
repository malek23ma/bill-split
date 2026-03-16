# Bill Split App — 10 Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the bill_split app from prototype to polished daily-use app with better split UX, settle up, dark mode, categories, monthly summary, settings screen, swipe-to-delete with undo, and animations.

**Architecture:** Incremental improvements on existing Provider + SQLite architecture. Database migration adds `category` and settlement support. New SettingsScreen centralizes config. Split UI moves from dropdown to chip-based Mine/Yours/Split pattern. All changes preserve backward compatibility with existing data.

**Tech Stack:** Flutter 3.41, Provider, SQLite (sqflite), SharedPreferences, Material 3

---

### Task 1: Database Migration — Add category column + settlement support

**Files:**
- Modify: `lib/database/database_helper.dart`
- Modify: `lib/models/bill.dart`

**Step 1:** Update `database_helper.dart`:
- Bump DB version from 1 to 2
- Add `onUpgrade` callback with:
  ```dart
  if (oldVersion < 2) {
    await db.execute("ALTER TABLE bills ADD COLUMN category TEXT DEFAULT 'other'");
  }
  ```
- Add `category` column to the `CREATE TABLE bills` statement for fresh installs

**Step 2:** Update `Bill` model:
- Add `category` field (String, default: `'other'`)
- Update `toMap()` and `fromMap()` to include category
- Update `copyWith()` if it exists

**Step 3:** Hot restart app, verify no crashes, existing bills load correctly.

---

### Task 2: Constants — Categories + Split Presets update

**Files:**
- Modify: `lib/constants.dart`

**Step 1:** Add `BillCategory` class:
```dart
class BillCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const BillCategory(this.id, this.label, this.icon, this.color);
}

class BillCategories {
  static const list = [
    BillCategory('groceries', 'Groceries', Icons.shopping_cart, Color(0xFF4CAF50)),
    BillCategory('restaurant', 'Restaurant', Icons.restaurant, Color(0xFFFF9800)),
    BillCategory('utilities', 'Utilities', Icons.bolt, Color(0xFF2196F3)),
    BillCategory('rent', 'Rent', Icons.home, Color(0xFF9C27B0)),
    BillCategory('transport', 'Transport', Icons.directions_car, Color(0xFF607D8B)),
    BillCategory('health', 'Health', Icons.local_hospital, Color(0xFFF44336)),
    BillCategory('entertainment', 'Entertainment', Icons.movie, Color(0xFFE91E63)),
    BillCategory('shopping', 'Shopping', Icons.shopping_bag, Color(0xFF00BCD4)),
    BillCategory('other', 'Other', Icons.receipt, Color(0xFF757575)),
  ];

  static BillCategory getById(String id) =>
      list.firstWhere((c) => c.id == id, orElse: () => list.last);
}
```

**Step 2:** Verify `SplitPresets` still has [50, 60, 70, 80, 100]. No changes needed.

---

### Task 3: Settings Screen + Dark Mode

**Files:**
- Create: `lib/screens/settings_screen.dart`
- Create: `lib/providers/settings_provider.dart`
- Modify: `lib/main.dart` (add route, wrap with SettingsProvider, use theme mode)
- Modify: `lib/screens/camera_screen.dart` (remove API key card)

**Step 1:** Create `settings_provider.dart`:
- `SettingsProvider extends ChangeNotifier`
- Fields: `ThemeMode themeMode`, `String apiKey`
- Load from SharedPreferences on init
- Methods: `setThemeMode()`, `setApiKey()`, `loadSettings()`

**Step 2:** Create `settings_screen.dart`:
- AppBar title: "Settings"
- Sections:
  1. **Appearance**: Dark mode toggle (ListTile with Switch)
  2. **AI Scanning**: API key text field with save button (moved from camera_screen)
  3. **About**: App version
- Read/write via SettingsProvider

**Step 3:** Update `main.dart`:
- Add `SettingsProvider` to `MultiProvider`
- Use `Consumer<SettingsProvider>` to set `themeMode` on `MaterialApp`
- Add dark theme: `darkTheme: ThemeData(colorSchemeSeed: Color(0xFF2E7D32), useMaterial3: true, brightness: Brightness.dark)`
- Add route: `'/settings': (_) => const SettingsScreen()`

**Step 4:** Update `camera_screen.dart`:
- Remove the API key card, `_apiKeyController`, `_loadApiKey`, `_saveApiKey`, `_hasApiKey`
- Read API key from `SettingsProvider` instead: `Provider.of<SettingsProvider>(context, listen: false).apiKey`

**Step 5:** Add settings gear icon to `home_screen.dart` app bar actions.

---

### Task 4: Item Row — Replace Dropdown with Mine/Yours/Split Chips

**Files:**
- Rewrite: `lib/widgets/item_row.dart`

**Step 1:** Replace the entire item row widget:
- Remove: Checkbox + Dropdown
- Add: Three `ChoiceChip` or small `FilledButton.tonal` buttons: Mine | Yours | Split
- Logic:
  - `Mine` → `isIncluded = true, splitPercent = 100` (current user keeps 100%)
  - `Yours` → `isIncluded = true, splitPercent = 0` (other person pays 100%)
  - `Split` → `isIncluded = true`, shows chip row below
- When `Split` is selected, show a row of `FilterChip` widgets: 50/50, 60/40, 70/30, 80/20
- Default state: `Split → 50/50`
- Item name and price displayed above the buttons
- Active button/chip gets primary color fill

**Step 2:** Update callbacks — the `onChanged` callback should pass back updated `BillItem` with new `isIncluded` and `splitPercent` values.

**Step 3:** Verify `item_review_screen.dart` works with the new widget (should work if callback signature unchanged).

---

### Task 5: Bill Categories UI

**Files:**
- Modify: `lib/screens/item_review_screen.dart`
- Modify: `lib/screens/quick_review_screen.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/bill_detail_screen.dart`
- Modify: `lib/providers/bill_provider.dart`

**Step 1:** Add category selector to `item_review_screen.dart` and `quick_review_screen.dart`:
- Horizontal scrollable row of `ChoiceChip` at the top (below date picker)
- Each chip shows icon + label from `BillCategories.list`
- Selected category stored in local state, passed to `saveBill()`

**Step 2:** Update `bill_provider.dart` `saveBill()` to accept and store `category`.

**Step 3:** Update bill list items in `home_screen.dart`:
- Replace hardcoded Quick/Full icons with category icon + color from `BillCategories.getById()`
- Keep bill type indicator as a small label/badge

**Step 4:** Update `bill_detail_screen.dart` to show category chip at top.

---

### Task 6: Settle Up Feature

**Files:**
- Modify: `lib/screens/home_screen.dart` (add button to balance card)
- Modify: `lib/providers/bill_provider.dart` (add settleUp method)

**Step 1:** Add `settleUp()` to `BillProvider`:
- Creates a special Bill with `billType = 'settlement'`, `category = 'settlement'`
- Amount = absolute value of current balance
- `paidByMemberId` = the member who owes money
- After insert, recalculate balances (should zero out)

**Step 2:** Add "Settle Up" button to the balance card in `home_screen.dart`:
- Only visible when balance != 0
- Confirmation dialog: "Mark ₺XX.XX as settled?"
- On confirm, call `billProvider.settleUp()`

**Step 3:** Display settlement bills in the list with handshake icon and "Settled up" label.

---

### Task 7: Monthly Summary

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/providers/bill_provider.dart` (add monthly stats getter)

**Step 1:** Add `MonthlySummary` model/getter to `BillProvider`:
- Calculate for current month: total bills count, your total spend, their total spend
- Expose as a getter

**Step 2:** Add collapsible summary card to `home_screen.dart` between balance card and bill list:
- Shows month name, bill count, each member's total spend
- `ExpansionTile` or simple `Card` — collapsed by default, tap to expand

---

### Task 8: Swipe to Delete + Undo

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1:** Wrap each bill `Card` in a `Dismissible` widget:
- `direction: DismissDirection.endToStart`
- Red background with trash icon
- `confirmDismiss`: return true
- `onDismissed`: show SnackBar with "Bill deleted" + UNDO action
- On dismiss: remove from list, delete from DB
- On UNDO: re-insert the bill and items

**Step 2:** Remove the delete button from `bill_detail_screen.dart` or keep it as secondary option.

---

### Task 9: Animations

**Files:**
- Modify: `lib/main.dart` (page transitions)
- Modify: `lib/screens/home_screen.dart` (list animations)

**Step 1:** Add slide page transitions in `main.dart`:
- Use `PageRouteBuilder` with `SlideTransition` for route generation
- Or use `onGenerateRoute` with custom transition builder

**Step 2:** Animate bill list items:
- Use `AnimatedList` or `ListView` with `TweenAnimationBuilder` for staggered fade-in

**Step 3:** Balance card number animation:
- Use `TweenAnimationBuilder<double>` to animate balance value changes

---

### Task 10: Final Polish + Hot Restart Test

**Step 1:** Hot restart, verify all features work together:
- Create a new bill with category, split items with Mine/Yours/Split
- Check monthly summary updates
- Toggle dark mode
- Settle up
- Swipe delete + undo
- Check animations

**Step 2:** Build release APK:
```
flutter build apk --release
```
