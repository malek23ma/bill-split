# Phase 4 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add settlement optimization, spending trend charts, category drill-down, and responsive sizing across the app.

**Architecture:** Settlement optimizer is a pure algorithm on existing pairwise balances. Spending trends and category drill-down extend InsightsScreen with new widgets. Responsive sizing adds a scale utility to constants and applies it across all 18 files with hardcoded sizes.

**Tech Stack:** Flutter, Provider, no new dependencies

---

## Task 1: Settlement Optimizer — Algorithm

**Files:**
- Modify: `lib/providers/bill_provider.dart`

**Step 1: Add Settlement data class and optimizer method**

After the `MonthlyInsights` class (around line 39), add:

```dart
class OptimalSettlement {
  final int fromMemberId;
  final int toMemberId;
  final double amount;

  OptimalSettlement({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}
```

Add method to `BillProvider`:

```dart
/// Compute minimum transfers to settle all debts.
/// Greedy algorithm: repeatedly match largest creditor with largest debtor.
List<OptimalSettlement> computeOptimalSettlements() {
  // Net out all pairwise balances per member
  final netBalances = <int, double>{};
  for (final entry in _pairwiseBalances.entries) {
    final memberId = entry.key;
    double net = 0;
    for (final val in entry.value.values) {
      net += val; // positive = owed to me, negative = I owe
    }
    if (net.abs() > 0.01) {
      netBalances[memberId] = net;
    }
  }

  final settlements = <OptimalSettlement>[];

  // Separate into creditors (positive) and debtors (negative)
  final creditors = netBalances.entries
      .where((e) => e.value > 0.01)
      .map((e) => MapEntry(e.key, e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final debtors = netBalances.entries
      .where((e) => e.value < -0.01)
      .map((e) => MapEntry(e.key, -e.value)) // make positive for easier math
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  int ci = 0, di = 0;
  while (ci < creditors.length && di < debtors.length) {
    final creditor = creditors[ci];
    final debtor = debtors[di];
    final amount = creditor.value < debtor.value ? creditor.value : debtor.value;

    settlements.add(OptimalSettlement(
      fromMemberId: debtor.key,
      toMemberId: creditor.key,
      amount: amount,
    ));

    creditors[ci] = MapEntry(creditor.key, creditor.value - amount);
    debtors[di] = MapEntry(debtor.key, debtor.value - amount);

    if (creditors[ci].value < 0.01) ci++;
    if (debtors[di].value < 0.01) di++;
  }

  return settlements;
}

/// Get raw pairwise debts as a flat list (for "All debts" view)
List<OptimalSettlement> getRawPairwiseDebts() {
  final debts = <OptimalSettlement>[];
  final seen = <String>{};
  for (final entry in _pairwiseBalances.entries) {
    for (final inner in entry.value.entries) {
      final key = '${entry.key < inner.key ? entry.key : inner.key}-${entry.key < inner.key ? inner.key : entry.key}';
      if (!seen.contains(key) && inner.value.abs() > 0.01) {
        seen.add(key);
        if (inner.value > 0) {
          // inner.key owes entry.key
          debts.add(OptimalSettlement(
            fromMemberId: inner.key,
            toMemberId: entry.key,
            amount: inner.value,
          ));
        } else {
          // entry.key owes inner.key
          debts.add(OptimalSettlement(
            fromMemberId: entry.key,
            toMemberId: inner.key,
            amount: -inner.value,
          ));
        }
      }
    }
  }
  return debts;
}
```

**Step 2: Commit**

```bash
git add lib/providers/bill_provider.dart
git commit -m "feat: add settlement optimizer algorithm with greedy min-transfers"
```

---

## Task 2: Settlement Optimizer — Settle All Sheet UI

**Files:**
- Create: `lib/widgets/settle_all_sheet.dart`

**Step 1: Create the Settle All bottom sheet**

A `StatefulWidget` shown in `showModalBottomSheet`. Takes:
- `List<OptimalSettlement> optimized` — the smart plan
- `List<OptimalSettlement> rawDebts` — all pairwise debts
- `Map<int, String> memberNames`
- `String currencySymbol`
- `Function(int fromId, int toId, double amount) onSettle` — callback to create settlement bill

UI structure:
- Drag handle
- Header: "Settlement Plan"
- `SegmentedButton<bool>` toggle: "Optimized (N)" / "All debts (N)"
- `ListView` of settlement rows, each showing:
  - "Name → Name" with arrow icon
  - Amount
  - "Pay" `FilledButton` that calls `onSettle`
- Follow app styling: isDark, AppColors, AppRadius

**Step 2: Commit**

```bash
git add lib/widgets/settle_all_sheet.dart
git commit -m "feat: add Settle All bottom sheet with optimized/raw toggle"
```

---

## Task 3: Settlement Optimizer — HomeScreen Integration

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Add "Settle All" button below balance cards**

After the `BalanceCard` widget (line 302), add:

```dart
// Settle All button
if (billProvider.pairwiseBalances.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showSettleAllSheet(context),
        icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
        label: Text('Settle All'),
        style: OutlinedButton.styleFrom(...),
      ),
    ),
  ),
```

**Step 2: Add `_showSettleAllSheet` method**

Opens `SettleAllSheet` with data from `billProvider.computeOptimalSettlements()` and `billProvider.getRawPairwiseDebts()`. The `onSettle` callback calls the existing `_confirmSettleUp` flow.

**Step 3: Add import for settle_all_sheet.dart**

**Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: integrate Settle All button on HomeScreen"
```

---

## Task 4: Spending Trends — Bar Chart

**Files:**
- Modify: `lib/screens/insights_screen.dart`

**Step 1: Add state for trend range**

Add to `_InsightsScreenState`:
```dart
int _trendMonths = 6;
```

**Step 2: Add `_buildSpendingTrends` method**

Between "By Category" and "By Member" sections (line 126), insert:

```dart
// Spending Trends section
_buildSectionTitle('Spending Trends', isDark),
const SizedBox(height: 12),
_buildSpendingTrends(billProvider, householdProvider, isDark),
const SizedBox(height: 24),
```

The `_buildSpendingTrends` method:
- SegmentedButton with 3M|6M|9M|12M at top
- Loop backward from current month for `_trendMonths` months
- Call `billProvider.getInsightsForMonth(year, month)` for each
- Find max total, render vertical bars proportional to max
- Each bar: `Container` with `Expanded` for height, fixed width
- Current month bar in `AppColors.primary`, others in muted color
- Amount above bar, month abbreviation below
- Wrap bars in a `Row` with `Expanded` children

**Step 3: Commit**

```bash
git add lib/screens/insights_screen.dart
git commit -m "feat: add spending trends bar chart with 3M/6M/9M/12M selector"
```

---

## Task 5: Category Drill-Down

**Files:**
- Modify: `lib/screens/insights_screen.dart`

**Step 1: Make category rows tappable**

In `_buildCategoryBreakdown`, wrap `_buildCategoryRow` call in a `GestureDetector`:

```dart
GestureDetector(
  onTap: () => _showCategoryDrillDown(sorted[i].key),
  child: _buildCategoryRow(sorted[i], maxAmount, insights.totalSpent, householdProvider, isDark),
),
```

**Step 2: Add `_showCategoryDrillDown` method**

```dart
void _showCategoryDrillDown(String categoryId) {
  final billProvider = context.read<BillProvider>();
  final householdProvider = context.read<HouseholdProvider>();
  final members = householdProvider.members;
  final currencySymbol = AppCurrency.getByCode(householdProvider.currency).symbol;
  final category = BillCategories.getById(categoryId);

  final filteredBills = billProvider.bills.where((b) =>
      b.category == categoryId &&
      b.billDate.year == _year &&
      b.billDate.month == _month &&
      b.billType != 'settlement').toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => FilteredResultsSheet(
        scrollController: scrollCtrl,
        filteredBills: filteredBills,
        filter: BillFilter(category: categoryId),
        members: members,
        currencySymbol: currencySymbol,
        onBillTap: (bill) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/bill-detail', arguments: bill);
        },
        onClearFilters: () {},
      ),
    ),
  );
}
```

**Step 3: Add imports for BillFilter and FilteredResultsSheet if not present**

**Step 4: Commit**

```bash
git add lib/screens/insights_screen.dart
git commit -m "feat: category drill-down — tap category to see matching bills"
```

---

## Task 6: Responsive Sizing — AppScale Utility

**Files:**
- Modify: `lib/constants.dart`
- Modify: `lib/main.dart`

**Step 1: Add AppScale class to constants.dart**

```dart
class AppScale {
  static double _scale = 1.0;

  static void init(double screenWidth) {
    _scale = (screenWidth / 375).clamp(0.85, 1.3);
  }

  static double fontSize(double base) => base * _scale;
  static double size(double base) => base * _scale;
  static double padding(double base) => base * _scale;
}
```

**Step 2: Initialize in main.dart**

In the root widget's build method, before returning MaterialApp, call:
```dart
AppScale.init(MediaQuery.of(context).size.width);
```

This requires wrapping MaterialApp in a Builder or using `WidgetsBinding.instance.window`.

Alternative: initialize lazily in AppScale itself using `WidgetsBinding`:
```dart
static void init(double screenWidth) {
  _scale = (screenWidth / 375).clamp(0.85, 1.3);
}
```

Call from a `Builder` widget wrapping the app content.

**Step 3: Commit**

```bash
git add lib/constants.dart lib/main.dart
git commit -m "feat: add AppScale responsive sizing utility"
```

---

## Task 7: Responsive Sizing — Apply to All Screens

**Files:**
- Modify: All 18 files with hardcoded font/size/padding values

**Step 1: Apply to large/prominent text sizes**

Priority targets (biggest visual impact):
- Balance card: amount fontSize 20/32 → `AppScale.fontSize(20/32)`
- Insights: total spent fontSize 32 → `AppScale.fontSize(32)`
- Section titles: fontSize 16-20 → `AppScale.fontSize()`
- Quick stats: fontSize 16 → `AppScale.fontSize(16)`
- Home screen: title fontSize 20 → `AppScale.fontSize(20)`

**Step 2: Apply to container sizes**

- Avatar containers: width/height 36/48/56 → `AppScale.size()`
- Icon sizes: 16/18/20/24/32 → `AppScale.size()`
- Card padding: 14/16/20/24 → `AppScale.padding()`

**Step 3: Apply to remaining screens**

Work through each screen file systematically:
- `home_screen.dart`
- `insights_screen.dart`
- `settings_screen.dart`
- `member_select_screen.dart`
- `household_screen.dart`
- `bill_detail_screen.dart`
- `camera_screen.dart`
- `item_review_screen.dart`
- `quick_review_screen.dart`
- `bill_type_screen.dart`
- All widgets in `lib/widgets/`

**Step 4: Skip small values**

Do NOT scale: border radii, divider widths (1-2px), tiny gaps (2-4px).

**Step 5: Run flutter analyze**

```bash
flutter analyze
```

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: apply responsive sizing across all screens and widgets"
```

---

## Task 8: Final Polish

**Files:**
- Modify: Various

**Step 1: Run flutter analyze and fix any issues**

```bash
flutter analyze
```

**Step 2: Test on different screen sizes**

Verify the app looks correct at various widths.

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: Phase 4 polish — lint fixes and final adjustments"
```
