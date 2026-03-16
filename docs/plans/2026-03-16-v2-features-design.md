# Bill Split v2 — Feature Design Document

> **Date:** 2026-03-16
> **Status:** Approved
> **For Claude:** Use superpowers:executing-plans to implement this plan phase-by-phase.

## Overview

Transform Bill Split from a 2-person bill splitter into a full-featured household finance app supporting N members, recurring bills, spending insights, export, currency flexibility, and cloud sync.

**Core UX principles:**
- Nobody gets lost — minimal navigation depth, bottom nav for primary views
- Easy access — one-tap actions, smart defaults
- Clean architecture — local-first, sync optional, data model scales to N members

**Tech Stack:** Flutter, Provider, SQLite (sqflite), Supabase (Phase 4), Google Fonts (Lexend), Material 3

---

## Architecture & Navigation

**Current:** Household → Member Select → Home → Add Bill → Camera → Review → Save

**New:**
```
Household → Member Select → Home (Bottom Nav)
                                ├── Bills tab
                                │     ├── Recurring bill banner (confirm/dismiss)
                                │     ├── Balance card (per-member balances)
                                │     ├── Bills list
                                │     └── FAB: Add Bill → Camera → Review → Save
                                └── Insights tab
                                      ├── Monthly spending bars by category
                                      ├── Member spending comparison
                                      ├── Month navigation
                                      └── Export button (Share / CSV / PDF)
```

Settings reorganized into: General (currency, dark mode), Receipt Scanning (API key), Security (PIN), About.

---

## Data Model (DB v4)

### Changed tables

**households** — add:
- `currency` TEXT DEFAULT 'TRY'

**bills** — add:
- `recurring_bill_id` INTEGER nullable (links to parent recurring bill)

**bill_items** — remove:
- ~`split_percent`~ (replaced by junction table)

### New tables

**bill_item_members** (junction table):
- `id` INTEGER PRIMARY KEY
- `bill_item_id` INTEGER FK
- `member_id` INTEGER FK
- One row per member sharing that item
- Equal split: `item.price / count(members for that item)`

**recurring_bills**:
- `id` INTEGER PRIMARY KEY
- `household_id` INTEGER FK
- `paid_by_member_id` INTEGER FK
- `category` TEXT
- `amount` REAL
- `title` TEXT
- `frequency` TEXT ('weekly', 'monthly', 'yearly')
- `next_due_date` TEXT
- `active` INTEGER DEFAULT 1

### Migration strategy

Existing `split_percent` data migrates to `bill_item_members`:
- `split_percent = 100` (Mine) → only current member in junction
- `split_percent = 0` (Yours) → only other member in junction
- Any other value → both members in junction (equal split)

Balance calculation changes from percentage-based to count-based:
- Each member's share of an item = `item.price / count(members on that item)`
- Member balance = sum of (items they're on) minus sum of (bills they paid)

---

## Screen UX Specifications

### Bills Tab (revised Home)

- AppBar: household name (left), settings gear + logout person icon (right)
- Recurring bill banner: only shows when a recurring bill is due. Shows title, amount, [Confirm] [Dismiss] buttons. On confirm: creates the bill with pre-filled data, advances next_due_date. On dismiss: snoozes until next day or skips.
- Balance card: shows per-member balances when 3+ members. Each row: "{Name} owes you {amount}" with individual Settle Up button. Single "All settled up!" when zero.
- Bills list: same as current with swipe-to-delete
- FAB: Add Bill

### Item Review Screen (multi-member)

- Per item: show all household members as small avatar chips (first letter of name)
- Tapped = sharing that item (filled chip), untapped = not sharing (outlined)
- Default: all members selected (split equally among all)
- Bottom summary: shows what each non-payer member owes
- Replaces Mine/Yours/Split — same concept, scales to N members

### Quick Review Screen

- Same as current but payer dropdown shows all N members
- Split preview shows equal share per member (total / N)

### Insights Tab

- Header: month name + Export button
- Total spent + bill count
- By Category: horizontal colored bars with percentage labels
- By Member: horizontal bars showing each member's total spend
- Month navigation: left/right arrows to browse history
- Export button: bottom sheet with Share (text), CSV, PDF options

### Settings (reorganized)

- GENERAL: Currency dropdown (TRY, USD, EUR, GBP, SAR, AED, etc.) + Dark mode segmented icons
- RECEIPT SCANNING: Groq API key with status dot
- SECURITY: Login PIN with status dot
- ABOUT: App name + version

Currency stored per-household, editable from Settings for current household.

---

## Implementation Phases

### Phase 1 — Foundation (multi-member)
1. DB migration v4: new tables, column changes, data migration
2. Update balance calculation engine for N members
3. New item assignment UI: member avatar chips per item
4. Update all screens to work with N members (balance card, review screens, bill detail, settle up)
5. Update household creation to allow 2+ member names

### Phase 2 — New features
6. Currency selector: household-level setting, currency symbol throughout UI
7. Bottom nav: Bills | Insights tabs on Home screen
8. Insights tab: category bars, member bars, month navigation (Option A: plain Flutter)
9. Recurring bills: model, creation UI (long-press bill → "Make recurring"), banner on Bills tab
10. Settings reorganization: General, Scanning, Security, About

### Phase 3 — Export & polish
11. Export: Share sheet (formatted text summary)
12. Export: CSV file
13. Export: PDF generation
14. Better OCR feedback: show raw scanned text alongside parsed items

### Phase 4 — Cloud sync
15. Supabase project setup + schema mirroring SQLite
16. Local-first sync engine: write to SQLite, push to Supabase, pull on login
17. Auth: email/password or magic link, multi-device support

### Optional: Phase 2.5 — Insights Option B
18. Build fl_chart version on separate branch, compare with Option A side by side

Each phase is independently shippable. The app works fully offline after every phase.

---

## Decisions Log

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Multi-member split | Assign members per item, equal split | Sweet spot between flexibility and speed |
| Settings layout | Grouped (General, Scanning, Security, About) | Fewer sections, related things together |
| Currency | One per household | Avoids exchange rate complexity |
| Recurring bills | Reminder banner + one-tap confirm | User stays in control, no silent surprises |
| Charts | Start with Option A (plain Flutter bars) | No dependency, swap to fl_chart later if needed |
| Export | All three (Share → CSV → PDF), built incrementally | Start simple, layer up |
| Cloud sync | Supabase | PostgreSQL matches SQLite schema, good free tier |
| Build order | Multi-member first | Changes data model fundamentally, everything else builds on it |
