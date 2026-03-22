# Phase 4 Design — Smarter Finances

**Date:** 2026-03-22
**Scope:** Settlement optimization, spending trends, category drill-down, responsive sizing.
**Order:** Settlement optimizer → Spending trends → Category drill-down → Responsive sizing

---

## 1. Settlement Optimizer

### Algorithm

Minimum transfers via greedy matching: net out all pairwise balances, then
repeatedly match the largest creditor with the largest debtor until all
balances reach zero. Produces at most N-1 transfers for N members.

### Data

New method `computeOptimalSettlements()` in `BillProvider`. Takes existing
pairwise balances, returns `List<Settlement>` where each Settlement has
`fromMemberId`, `toMemberId`, `amount`. Pure computation, no DB changes.

### UI

- "Settle All" button below balance cards on HomeScreen
- Tapping opens a bottom sheet:
  - Header: "Settlement Plan — N transfers"
  - Toggle: "Optimized" / "All debts" (segmented button)
  - List of transfers: "Malook → Zanzooon: 200 ₺" with "Pay" button each
  - "Pay" creates a settlement bill (reuses existing settleUp flow)
- Individual "Settle Up" buttons on balance cards remain unchanged

---

## 2. Spending Trends

### Chart

Vertical bar chart built with Flutter Container widgets (no new dependencies).
Each bar = one month's total spend, proportional to the highest month.
Current month highlighted in primary blue, past months in muted color.
Amount shown above each bar, month abbreviation below.

### Time Range

SegmentedButton above the chart: 3M | 6M | 9M | 12M. Default: 6M.
Empty months render a thin baseline bar.

### Location

New section in Insights screen between "By Category" and "By Member".
Title: "Spending Trends".

### Data

Loop over `getInsightsForMonth()` for each month in range. Bills already
in memory, so this is filtering only — no new DB queries.

---

## 3. Category Drill-Down

### Interaction

Each category row in Insights "By Category" section becomes tappable.
Tap opens a bottom sheet showing all bills in that category for the
currently selected month.

### Implementation

Reuse `FilteredResultsSheet`. On tap:
1. Filter `billProvider.bills` by category + selected month/year
2. Open FilteredResultsSheet with filtered bills and category name as summary

Changes: wrap `_buildCategoryRow` in `GestureDetector`. No new widgets
or data structures needed.

---

## 4. Responsive Sizing

### Utility

New `AppScale` class in `lib/constants.dart`:
- Base width: 375 (standard phone)
- Scale factor: `screenWidth / 375`, clamped to `[0.85, 1.3]`
- Methods: `fontSize(base)`, `size(base)`, `padding(base)`
- Initialize via MediaQuery, accessible statically after init

### Audit Scope

Replace hardcoded values across all screens and widgets:
- Font sizes (especially large: balance amounts, totals, titles)
- Icon/avatar container sizes (36, 48, 56px)
- Card padding and margins
- Button heights and padding

### Excluded from Scaling

Small fixed values: 2px dividers, 4px gaps, border radii. These are
fine at fixed sizes across devices.

---

## Files Affected (Estimated)

| Feature | New Files | Modified Files |
|---------|-----------|----------------|
| Settlement optimizer | `lib/widgets/settle_all_sheet.dart` | `bill_provider.dart`, `home_screen.dart` |
| Spending trends | — | `insights_screen.dart` |
| Category drill-down | — | `insights_screen.dart` |
| Responsive sizing | — | `constants.dart`, all screens and widgets |
