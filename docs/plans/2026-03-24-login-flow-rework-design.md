# Login Flow UX Rework Design

**Goal:** Simplify the app flow so that auth account = member identity. Remove member select screen, local-only mode, and per-member PINs. Add household switcher dropdown and per-account app lock.

---

## 1. App Launch Flow

1. App opens → check Supabase auth session
2. **Not logged in** → Sign up / Sign in screen (no "Continue without account")
3. **Logged in, has passcode** → Passcode screen → then home
4. **Logged in, no passcode** → straight to home
5. Home screen shows last-used household automatically
6. If user has no households → "Create Household" or "Join Household" screen

**Removed:**
- Onboarding screen's "Continue without account" button
- Member select screen entirely — auth account IS the member
- Per-member PIN system (replaced by per-account passcode)

---

## 2. Household & Member Identity

- Creating a household auto-creates a member linked to the auth user's `user_id` and display name
- Joining a household via invite claims an existing member or creates a new one, linked to `user_id`
- No member select screen — `currentMember` is determined by: `members.user_id == auth.uid()` in the current household
- Adding members: invite only (no "Add Member" by name for cloud users)

### Household Switching

- Home screen app bar shows current household name (tappable)
- Tap → dropdown lists all households where user is a member
- Tap a different household → switches context, reloads bills/balances
- Last-used household stored in SharedPreferences

---

## 3. Passcode (App Lock)

- One passcode per account, used as app lock on launch
- Stored in FlutterSecureStorage, keyed by auth user ID
- Set/change/remove in Settings under "App Lock" section
- On app launch: after auth check, before home → passcode screen if enabled

---

## 4. Settings Screen Changes

**Removed:**
- Member list with per-member PINs
- "Add Member" by name button
- Member long-press rename/delete

**Changed:**
- "App Lock" section replaces PIN section — single toggle + passcode
- Account info at top: display name, email

**Kept:**
- Currency selection
- Theme toggle
- Manage Recurring Bills
- Invite Members (admin only)
- Sign Out
- Household name/delete

---

## Architecture Summary

| Component | Change |
|---|---|
| App launch | Auth check → passcode → home (no member select) |
| Identity | Auth account = member, auto-linked by user_id |
| Household switching | Dropdown in home screen app bar |
| Adding members | Invite only, no local "Add Member" |
| Passcode | Per-account app lock, replaces per-member PINs |
| Local-only mode | Removed entirely |
| Settings | Simplified, no member list/PINs |
