# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (requires a connected device or emulator)
flutter run

# Analyze/lint
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build release APK
flutter build apk --release
```

## Architecture Overview

**bill_split** is a Flutter app for splitting household bills. It uses **Provider** for state management and **SQLite (sqflite)** for local persistence. There is no backend — all data lives on-device.

### State Management

Four `ChangeNotifier` providers are registered at the root in `main.dart`:

- `HouseholdProvider` — manages households, members, and the currently active household/member session
- `BillProvider` — loads bills, computes member balances and monthly summaries/insights, and persists bills + items
- `RecurringBillProvider` — tracks due recurring bills and creates actual bills when confirmed
- `SettingsProvider` — persists theme mode and the Groq API key via `shared_preferences`

Providers call `DatabaseHelper.instance` (singleton) directly; there is no repository layer.

### Database (`lib/database/database_helper.dart`)

SQLite schema at version 4. Tables:

- `households` — id, name, currency (default TRY), created_at
- `members` — id, household_id, name, pin (nullable)
- `bills` — id, household_id, entered_by_member_id, paid_by_member_id, bill_type (`full`/`quick`/`settlement`), total_amount, photo_path, bill_date, category, recurring_bill_id
- `bill_items` — id, bill_id, name, price, is_included
- `bill_item_members` — junction table linking bill items to member IDs (who shares each item)
- `recurring_bills` — id, household_id, paid_by_member_id, category, amount, title, frequency, next_due_date, active

`_onUpgrade` handles incremental migrations from each version.

### Bill Types and Balance Calculation

`BillProvider._calculateBalances` computes per-member net balances differently per bill type:

- **`full`**: Per-item; each item's cost is split evenly among `sharedByMemberIds`. Payer is credited what others owe.
- **`quick`**: Total split equally among all household members.
- **`settlement`**: Resets balances — payer is credited the full amount, others are debited equally.

`BillItem.splitPercent` is **deprecated**. All code should use `sharedByMemberIds` (a `List<int>` of member IDs sharing the item).

### Receipt Scanning Pipeline

`CameraScreen` handles two scanning paths:

1. **AI (cloud)**: If a Groq API key is set in settings, `CloudReceiptScanner` sends the image as base64 to `https://api.groq.com/openai/v1/chat/completions` using model `meta-llama/llama-4-scout-17b-16e-instruct`. Returns structured JSON with items, total, date, and category.
2. **On-device (local)**: `ReceiptScanner` preprocesses the image (grayscale → normalize → contrast boost) and runs Google ML Kit OCR. `ReceiptParser` then extracts items and totals using regex patterns tuned for **Turkish receipts** (skip keywords like TOPLAM, KDV, NAKIT; handles both comma-decimal and period-decimal price formats).

Scanned receipt images are permanently copied to `getApplicationDocumentsDirectory()/receipt_photos/`.

### Navigation

Named routes defined in `main.dart`. The typical user flow:

```
/ (HouseholdScreen)
  → /select-member (MemberSelectScreen)
    → /home (HomeScreen — Bills tab + Insights tab)
      → /bill-type (BillTypeScreen)
        → /camera (CameraScreen)  [passes bill type as argument]
          → /item-review (ItemReviewScreen)   [full bills]
          → /quick-review (QuickReviewScreen) [quick bills]
      → /bill-detail (BillDetailScreen)
      → /settings (SettingsScreen)
```

### Constants (`lib/constants.dart`)

Central definitions for:
- `AppColors` — full light and dark palette
- `AppRadius` — border radius scale (xs/sm/md/lg/xl/xxl)
- `AppCurrency` — supported currencies (TRY default, USD, EUR, GBP, SAR, AED, JPY, KRW)
- `BillCategories` — 9 categories (groceries, restaurant, utilities, rent, transport, health, entertainment, shopping, other)
- `SplitPresets` — preset split percentages (50/60/70/80)

### Theming

The app uses **Material 3** with the **Lexend** font (via `google_fonts`). Light/dark/system theme is driven by `SettingsProvider.themeMode`. Full theme configuration (colors, button shapes, card borders, etc.) is defined in `main.dart`.
