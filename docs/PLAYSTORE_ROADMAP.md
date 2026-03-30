# BillSplit — Play Store Publication Roadmap

> **Last updated:** 2026-03-30
> **Current status:** ~70% Play Store ready
> **Current branch:** `performance-optimization` (not yet merged to master)

---

## Where We Are Now

All core features are built and working:
- Auth (email, phone, Google, Apple)
- Households, members, invites, roles
- Full/Quick/Settlement bill creation with item-level splitting
- Receipt scanning (local OCR + cloud AI via Groq)
- Cloud sync (SQLite <-> Supabase, offline-first)
- Real-time notifications (Supabase Realtime + FCM)
- Settlement optimizer with confirmation flow
- Recurring bills, insights, CSV export
- Dark/Light theme, responsive design

**What's NOT done:** Production infrastructure (signing, security, monitoring) and publication assets. The app works — it just isn't ready to ship to strangers yet.

---

## Pre-Phase: Merge Performance Branch

**Status:** Must do first before any phase work

Before starting Phase 1, the `performance-optimization` branch (8+ commits ahead of master) needs to be tested and merged. It contains:
- DB v11->12: 13 indexes on all FK and query columns
- Batch queries eliminating N+1 in balance calc, member loading, CSV export
- Parallel Supabase sync via `Future.wait()`
- Cached `thisMonthTotal` / `lastMonthTotal` / settlements in BillProvider
- Home screen shows local data first, syncs in background
- Image capture quality reduced (100->80, resolution 2560->1600)

**Action:** Test on phone -> fix any issues -> merge to master.

---

## Phase 1: Production Infrastructure (CRITICAL — Blocks submission)

> Without these, the Play Store will reject the app or users' data is at risk.

### 1.1 Release Signing Config
- **What:** Generate a production keystore and configure `android/app/build.gradle.kts` for release signing
- **Why:** Play Store requires APKs/AABs signed with a release key, not debug keys
- **How:** Generate keystore via `keytool`, create `key.properties`, reference in Gradle
- **Note:** Google Play App Signing is now required for new apps — you upload your key to Google and they manage it. This protects you if you lose the local keystore.

### 1.2 Re-enable Supabase RLS
- **What:** Turn Row-Level Security back ON for all tables with production-safe policies
- **Why:** RLS is currently DISABLED. Any authenticated user can read/write ALL data (every household, every bill, every member). This is a critical security hole.
- **How:** Re-enable RLS, keep INSERT policies permissive for bootstrap (new user creating household), restrict SELECT/UPDATE/DELETE to household members only
- **Gotcha:** The `is_household_member()` function has a chicken-and-egg problem for first-time sync. INSERT policies must allow authenticated users without membership checks.

### 1.3 Deploy send-push Edge Function
- **What:** Deploy the `send-push` Edge Function to Supabase + set `FCM_SERVER_KEY` env var + create database webhook on `notifications` INSERT
- **Why:** Push notifications are built in the app but the server-side delivery doesn't exist yet. Notifications will only work via Supabase Realtime (app must be open).
- **How:** `supabase functions deploy send-push`, then set secrets and create webhook in dashboard

### 1.4 Fix App Identity
- **What:**
  - Change `applicationId` from `com.malek.billsplit.bill_split` to `com.malek.billsplit` (cleaner)
  - Change Android app label from `bill_split` to `BillSplit` (or whatever final name you choose)
  - Update pubspec.yaml `description` from "A new Flutter project." to a real description
- **Why:** Users and the Play Store see these values. "bill_split" looks unfinished.
- **Important:** Once you publish with an applicationId, you can NEVER change it. Pick it carefully.

### 1.5 Privacy Policy
- **What:** Write and host a privacy policy page
- **Why:** Play Store requires a privacy policy URL during submission. You collect email, phone numbers, photos, and financial data — this is mandatory.
- **How:** Use a free privacy policy generator, host on GitHub Pages or a simple website
- **Must cover:** Data collected (email, financial info, photos), how it's stored (Supabase, Firebase), third-party services (Google, Apple, Groq), data deletion rights

---

## Phase 2: Stability & Monitoring (IMPORTANT — Ship with confidence)

> These make the difference between "published" and "maintainable in production."

### 2.1 Firebase Crashlytics
- **What:** Add `firebase_crashlytics` package, initialize in `main.dart`, wrap `runApp` in crash zone
- **Why:** Without this, when production users crash, you'll never know. You'll get 1-star reviews with "app crashes" and no way to diagnose.
- **How:** ~10 lines of setup code. Firebase project already exists.

### 2.2 App Lifecycle Handling
- **What:** Add `AppLifecycleListener` to pause sync when backgrounded, refresh data when foregrounded
- **Why:** Currently sync runs regardless of app state. This wastes battery and could cause issues with stale connections.
- **Fix:**
  - `paused` -> pause sync, cancel realtime subscriptions
  - `resumed` -> refresh data, reconnect realtime, check connectivity
  - `detached` -> cleanup resources

### 2.3 Basic Accessibility
- **What:** Add `semanticLabel` to all interactive elements (buttons, form fields, images), add `Semantics` widgets to balance cards and custom components
- **Why:** Google Play encourages accessibility. Screen reader users (TalkBack) can't navigate the app currently. Only 7 tooltip labels exist in the entire app.
- **Scope:** Focus on auth flow, home screen, bill creation, and settings — the most-used screens.

### 2.4 Custom Exception Classes
- **What:** Replace generic `throw Exception('...')` with typed exceptions (AuthException, SyncException, etc.)
- **Why:** Generic exceptions leak internal details in error messages and make error handling fragile. Custom types let you show user-friendly messages while logging technical details.

---

## Phase 3: Play Store Submission (GET PUBLISHED)

> This is the actual submission process. Everything before this must be done.

### 3.1 App Icon Polish
- **What:** Verify app icon looks correct at all densities (mdpi through xxxhdpi). Consider using adaptive icons (foreground + background layers) for Android 8+.
- **Why:** The icon is the first thing users see. Current icon is 442 bytes in mdpi — verify it's not a placeholder.

### 3.2 Store Listing Assets
- **What:** Create the following:
  - **Screenshots:** At least 2 phone screenshots (recommended: 4-8 showing key features)
  - **Feature graphic:** 1024x500 banner image
  - **Short description:** Max 80 characters
  - **Full description:** Max 4000 characters, highlight key features
- **Why:** Play Store requires these for listing. Better assets = more downloads.

### 3.3 Build Release AAB
- **What:** Run `flutter build appbundle --release` to generate the signed Android App Bundle
- **Why:** Google Play requires AAB format (not APK) for new apps since 2021
- **Verify:** Test the release build on your phone before uploading

### 3.4 Google Play Console Setup
- **What:** Create developer account ($25 one-time fee), create app listing, set up content rating questionnaire, target audience, data safety section
- **Why:** Required steps in Play Console before you can upload
- **Data safety section:** Must declare: email collection, financial data, photos, analytics, crash reports

### 3.5 Submit for Review
- **What:** Upload AAB, complete all required sections, submit for review
- **Timeline:** First review typically takes 1-3 days for new developers. May take longer.
- **Common rejection reasons:** Missing privacy policy, incorrect data safety declarations, app crashes during review

---

## Phase 4: Post-Launch Polish (NICE TO HAVE — iterate after publishing)

> These improve the app but don't block publication. Ship first, polish second.

### 4.1 Turkish Localization
- **What:** Add `.arb` files for Turkish, set up Flutter's `l10n` system, translate all user-facing strings
- **Why:** Your target market is Turkey. TRY is the default currency. Turkish-speaking users will expect a Turkish UI.
- **Scope:** ~200-300 strings to translate across 14 screens
- **Package:** `intl` is already in pubspec — just needs `.arb` files and generation setup

### 4.2 Deep Linking
- **What:** Add intent-filter to AndroidManifest.xml, set up URL scheme handling, route incoming links to correct screens
- **Why:** When users share invite links, tapping the link should open the app directly to the join screen — not just copy a code.
- **How:** Firebase Dynamic Links or custom `https://` domain with `assetlinks.json`

### 4.3 Image Caching
- **What:** Add `cached_network_image` package for receipt photos loaded from Supabase Storage
- **Why:** Currently, cloud-stored receipt photos are re-downloaded every time. Caching saves bandwidth and makes the app feel faster.

### 4.4 Bill Search
- **What:** Add a search bar to the bill list on home screen. Search by item name, category, amount, payer.
- **Why:** As users accumulate hundreds of bills, scrolling and filtering isn't enough. Full-text search is a standard expectation.

### 4.5 Integration Tests
- **What:** Write tests for critical flows: auth -> create household -> add bill -> view balance -> settle
- **Why:** Currently zero meaningful tests. Every update risks breaking something silently. Tests protect you during future development.
- **Framework:** Flutter integration_test package, test on a real device or emulator

---

## Phase 5: UX Refinements (NICE TO HAVE — quality of life)

> Small improvements that make the app feel more polished and professional.

### 5.1 Bill Editing
- **What:** Allow users to edit existing bills (change amount, items, payer, date, category) instead of requiring delete + recreate
- **Why:** Currently the only way to fix a mistake is to delete the bill and create a new one. This is frustrating and loses the original timestamp/history.
- **Considerations:**
  - Must handle sync: edited bill needs `updated_at` bump and cloud push
  - Must recalculate balances after edit
  - Settlement bills should NOT be editable (they're part of the confirmation flow)
  - Admin vs member permissions for editing others' bills

### 5.2 Offline Indicator
- **What:** Show a visual banner or icon when the device is offline, and a brief toast when connectivity is restored
- **Why:** Users don't know when they're offline. They might wonder why their bill didn't appear on another device, or why a settlement confirmation isn't going through.
- **How:** `ConnectivityService` already monitors status — just expose it to the UI layer via a banner widget at the top of the screen or a colored status bar indicator.
- **UX:**
  - Offline: subtle orange/gray bar at top — "You're offline. Changes will sync when connected."
  - Back online: brief green toast — "Back online. Syncing..." then disappear

### 5.3 Sync Retry with Backoff
- **What:** When a sync queue entry fails, retry it with exponential backoff instead of dropping it
- **Why:** Currently, failed sync entries are skipped and cleaned up. If Supabase has a temporary outage or the network is flaky, user data could be lost (local change made but never pushed to cloud).
- **How:**
  - Add `retry_count` and `next_retry_at` columns to `sync_queue` table
  - On failure: increment retry_count, set next_retry_at = now + (2^retry_count) seconds
  - Max retries: 5 (then mark as permanently failed and notify user)
  - On connectivity restore: process only entries where `next_retry_at < now`
- **Important:** This is the biggest reliability improvement you can make to the sync system

---

## Summary Table

| Phase | Priority | Items | Theme |
|-------|----------|-------|-------|
| Pre-Phase | Merge first | 1 | Merge perf branch to master |
| Phase 1 | CRITICAL | 5 items | Production infrastructure — blocks submission |
| Phase 2 | IMPORTANT | 4 items | Stability, monitoring, accessibility |
| Phase 3 | REQUIRED | 5 items | Actual Play Store submission process |
| Phase 4 | Nice to have | 5 items | Post-launch polish and features |
| Phase 5 | Nice to have | 3 items | UX refinements and reliability |

---

## Quick Reference: What Goes Where

| Task | Phase | Type |
|------|-------|------|
| Merge perf branch | Pre | Must do |
| Release keystore + signing | 1.1 | Fix |
| Re-enable Supabase RLS | 1.2 | Fix (security) |
| Deploy send-push Edge Function | 1.3 | Fix (feature gap) |
| Fix applicationId + app name | 1.4 | Fix (identity) |
| Privacy policy | 1.5 | Add |
| Firebase Crashlytics | 2.1 | Add |
| App lifecycle handling | 2.2 | Add |
| Accessibility labels | 2.3 | Enhance |
| Custom exception classes | 2.4 | Enhance |
| App icon verification | 3.1 | Verify |
| Store listing assets | 3.2 | Add |
| Build release AAB | 3.3 | Build |
| Play Console setup | 3.4 | Setup |
| Submit for review | 3.5 | Submit |
| Turkish localization | 4.1 | Add |
| Deep linking | 4.2 | Add |
| Image caching | 4.3 | Enhance |
| Bill search | 4.4 | Add |
| Integration tests | 4.5 | Add |
| Bill editing | 5.1 | Add |
| Offline indicator | 5.2 | Add |
| Sync retry with backoff | 5.3 | Enhance (reliability) |
