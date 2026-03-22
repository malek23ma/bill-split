# Phase 5a Design — Cloud Foundation (Supabase)

**Goal:** Move from a fully local app to a cloud-synced architecture with real user accounts, while keeping the app functional offline.

**Phase 5b (later):** Settlement confirmation flow, push notifications (FCM), household invites (link/code, email/phone, QR).

---

## 1. Supabase Schema

The cloud DB mirrors the local SQLite schema with cloud-native additions.

### Universal columns (every table)

- `id` — UUID (replaces auto-increment integer)
- `created_at` — timestamptz, server-set
- `updated_at` — timestamptz, auto-updated on every write
- `deleted_at` — timestamptz nullable, soft delete for sync

### New tables

**`profiles`**
- `id` UUID PK (= auth.users.id)
- `display_name` TEXT NOT NULL
- `avatar_url` TEXT nullable
- `created_at` timestamptz

**`sync_log`**
- `id` UUID PK
- `device_id` TEXT NOT NULL
- `household_id` UUID FK
- `last_synced_at` timestamptz

### Modified tables

**`members`** gains:
- `user_id` UUID nullable FK → auth.users — linked when a real user claims the member

**`bills`** gains:
- `photo_url` TEXT nullable — cloud storage URL
- `deleted_by_user_id` UUID nullable — tracks who deleted (for admin-delete notifications)

### Foreign keys

All FKs shift from integer to UUID. Locally, SQLite keeps integer `id` as primary key and stores the UUID as a `remote_id` TEXT column for mapping.

### Row Level Security (RLS)

- Users can only read/write data in households they belong to (verified via members.user_id)
- Bill deletion: only the payer (`paid_by_member_id` → member.user_id) OR a household admin
- Members table: only admins can soft-delete/rename other members

---

## 2. Authentication

### Sign-up options (user picks one)
- Email + password
- Phone + OTP (SMS)

### Optional linking after sign-up
- Google sign-in
- Apple sign-in

### App flow

1. First launch → onboarding: "Sign up" or "Continue without account" (app stays usable locally)
2. Sign up → Supabase auth user created → `profiles` row created → household screen
3. Existing local users → "Upload existing data?" prompt before proceeding

### Member-to-user linking

- Joining a household claims a member slot — that member's `user_id` is set to the auth user ID
- Unclaimed members (no `user_id`) show in the household but aren't linked to a real account — admin can invite someone to claim them

### Session management

- Supabase handles token refresh automatically
- PIN system becomes optional/deprecated for cloud users — real auth replaces it
- PINs still work for local-only users who haven't signed up

---

## 3. Sync Architecture

### Repository Pattern

**`SupabaseRepository`** mirrors `DatabaseHelper`'s API (same method signatures) but talks to Supabase instead of SQLite. Providers are injected with whichever repository is appropriate based on auth state.

### Components

1. **`SupabaseRepository`** — cloud CRUD operations
2. **`SyncService`** — background reconciliation between local SQLite and Supabase:
   - On app open: pull remote changes since last sync timestamp
   - On connectivity restored: push queued local changes, then pull
   - On write: write to local SQLite immediately (fast UX), queue a push to Supabase
3. **`SyncQueue`** table in local SQLite — pending operations:
   - `id`, `table_name`, `row_id`, `operation` (insert/update/delete), `payload` (JSON), `created_at`
   - Processed FIFO when online, cleared after successful push
4. **`ConnectivityService`** — listens to network state, triggers sync on reconnection

### Conflict resolution

- `updated_at` timestamp on every row
- Last write wins: remote `updated_at` > local → remote wins, otherwise local wins
- Deletions: `deleted_at` with newer timestamp wins over an edit with older timestamp

### ID mapping

- Local SQLite keeps integer `id` as primary key (nothing breaks)
- Adds `remote_id` (UUID TEXT) column to every synced table
- `SyncService` maps between the two when pushing/pulling

### What syncs

- households, members, bills, bill_items, bill_item_members, recurring_bills
- NOT synced: settings (theme, API key), bill_filter (ephemeral state)

---

## 4. Bill Deletion Permissions

### Rules

- **Payer** (`paid_by_member_id`) can delete their own bills
- **Admin** (`is_admin = true`) can delete any bill in the household
- **All others**: delete option is hidden

### Implementation

- `BillDetailScreen` checks: `bill.paidByMemberId == currentMember.id || currentMember.isAdmin`
- If not authorized, delete option is not shown
- Swipe-to-delete on home screen follows the same permission check
- When admin deletes another member's bill, a notification record is created (type: `admin_bill_delete`) referencing the bill info and the payer's user ID

---

## 5. Receipt Photo Upload

### Upload flow

1. User takes/selects receipt photo
2. Compressed client-side: max 1200px wide, JPEG quality 70%
3. Bill saved to local SQLite with local `photo_path` as before
4. `SyncService` detects bill has a photo → uploads to Supabase Storage: `receipts/{household_id}/{bill_remote_id}.jpg`
5. On success, `photo_url` column is populated on both local and remote bill row

### Viewing

- App checks `photo_url` first (cloud), falls back to `photo_path` (local file)
- Other household members can view receipts via the cloud URL

### Storage bucket RLS

- Read: any member of the household
- Write: authenticated users in the household
- Delete: bill payer or admin only

### Cleanup

- When a bill is deleted, the associated photo is removed from the bucket

---

## 6. Local Data Migration

### Trigger

User has existing local data (bills > 0) and signs up for Supabase for the first time.

### Flow

1. After auth completes, check if local households/bills exist
2. If yes → bottom sheet: "You have existing data (X bills across Y households). Upload to your new account?"
3. **"Upload"**:
   - Create households in cloud, receive UUIDs
   - Map local integer IDs to remote UUIDs
   - Upload members, bills, bill_items, bill_item_members, recurring_bills in dependency order
   - Upload receipt photos
   - Populate `remote_id` on all local rows
   - Show progress indicator
4. **"Start fresh"**: local data stays but isn't synced, user gets an empty cloud account

### Error handling

- If upload fails mid-way (network drops), resume from where it left off
- Rows with an existing `remote_id` are skipped on retry

---

## Architecture Summary

| Component | Approach |
|---|---|
| Schema | UUID-based, soft deletes, `updated_at` for sync |
| Auth | Email/phone primary, Google/Apple optional link |
| Sync | Repository pattern, local-first writes, background sync queue |
| Conflicts | Last write wins via `updated_at` timestamps |
| Deletion perms | Payer or admin only, admin deletes notify payer |
| Photos | Compressed upload to Supabase Storage bucket |
| Data migration | User-prompted upload or fresh start |
| Real-time | Critical events only (settlements, notifications) — Phase 5b |
