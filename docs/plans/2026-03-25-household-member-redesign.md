# Household & Member Redesign

**Date:** 2026-03-25
**Branch:** login-flow-rework
**Status:** Approved

## Problem

The current household-member system has structural issues:
1. Members are name-only strings with no reliable link to auth accounts
2. `resolveCurrentMember()` uses 5 fragile heuristics to guess which member is the logged-in user
3. Household creation forces 2+ member names — but only one gets linked to an auth account
4. Notifications are not scoped to households — all notifications from all households mix together
5. Local SQLite has no `user_id` on members, making offline resolution impossible
6. Cloud filtering hides households when `user_id` linking fails

## Design Decisions

1. **One account = one member.** No more name-only members. Every member is a real auth user.
2. **Invite codes only.** Members join via invite code. No invite-by-email for now.
3. **Notifications scoped to current household.** Switch household = see that household's notifications.
4. **Passcode removed.** Will be re-added later as a separate feature.

## New App Flow

```
LaunchScreen
├── No auth → AuthScreen (Sign Up / Sign In)
│   └── Success → HouseholdGate
└── Has auth → HouseholdGate
    ├── last_household_id valid + member resolves → HomeScreen
    └── Otherwise → HouseholdPickerScreen
        ├── "Create Household" → name only → auto-member → HomeScreen
        └── "Join Household" → enter invite code → HomeScreen
```

## Member Model

| Field | Type | Notes |
|-------|------|-------|
| id | int? | Local SQLite PK |
| household_id | int | FK to household |
| user_id | String | Auth user ID — required for new members |
| name | String | Display name from profile |
| is_admin | bool | Household admin |
| is_active | bool | Soft-delete |
| remote_id | String? | Supabase UUID |
| created_at | DateTime | Timestamp |
| updated_at | String? | Conflict resolution |

Removed: `pin` field.

## Household Creation

1. User enters household name only (+ currency)
2. One member auto-created: name = display_name, user_id = authUser.id, is_admin = true
3. Set as current household, save to SharedPreferences
4. Cloud sync best-effort (doesn't block entry)
5. Navigate to HomeScreen

## Notification Scoping

- `loadNotifications()` takes `householdRemoteId` parameter
- Query adds `.eq('household_id', householdRemoteId)`
- Realtime subscription also filtered by household_id
- Switching households reloads notifications
- Badge = current household unread only

## Removed

- Passcode screen + PasscodeService
- `pin` field on Member
- 5-strategy `resolveCurrentMember()` — replaced by `WHERE user_id = ?`
- Member name fields in household creation
- `_syncUnsyncedHouseholds()` in household_screen
- `getHouseholdsForUser()` cloud filter
- Onboarding screen route
