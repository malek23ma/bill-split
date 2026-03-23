# Phase 5b Design — Social Features (Notifications, Settlements, Invites)

**Goal:** Add settlement confirmation flow, push notifications, and household invites so users on separate devices can interact in real time.

**Depends on:** Phase 5a (Supabase auth, sync, cloud DB).

---

## 1. Notifications System

### New Supabase tables

**`notifications`**
- `id` UUID PK
- `household_id` UUID FK → households
- `recipient_user_id` UUID FK → auth.users
- `sender_user_id` UUID FK → auth.users
- `type` TEXT — `settlement_request`, `settlement_confirmed`, `settlement_rejected`, `admin_bill_delete`, `household_invite`
- `title` TEXT
- `body` TEXT
- `data` JSONB — type-specific payload
- `read` BOOLEAN DEFAULT false
- `created_at` TIMESTAMPTZ

**`device_tokens`**
- `id` UUID PK
- `user_id` UUID FK → auth.users
- `fcm_token` TEXT NOT NULL
- `device_id` TEXT NOT NULL
- `updated_at` TIMESTAMPTZ

### Behavior

- App registers FCM tokens on login, removes on logout
- Supabase Edge Function watches `notifications` inserts and sends FCM pushes
- App subscribes to Supabase Realtime for instant in-app updates
- Notifications persist in the table for inbox history

---

## 2. Settlement Confirmation Flow

### New Supabase table

**`settlements`**
- `id` UUID PK
- `household_id` UUID FK → households
- `from_member_id` UUID FK → members (payer)
- `to_member_id` UUID FK → members (receiver)
- `amount` DOUBLE PRECISION
- `status` TEXT — `pending`, `confirmed`, `rejected`
- `created_by_user_id` UUID FK → auth.users
- `confirmed_at` TIMESTAMPTZ nullable
- `rejected_at` TIMESTAMPTZ nullable
- `created_at` TIMESTAMPTZ

### Flow

1. User A taps "Pay" → creates `settlements` row with `status: pending` → notification sent to User B
2. **No bill created yet** — balances don't change while pending
3. User B sees notification → taps Confirm or Reject
4. **Confirm:** status → `confirmed`, settlement bill created in `bills`, balances update, notification sent to User A
5. **Reject:** status → `rejected`, no bill created, notification sent to User A

### UI changes

- "Pay" buttons create pending settlements instead of immediate bills
- Individual "Settle Up" buttons do the same
- Pending settlements show in notifications screen with Confirm/Reject buttons

---

## 3. Household Invites

### New Supabase table

**`household_invites`**
- `id` UUID PK
- `household_id` UUID FK → households
- `invited_by_user_id` UUID FK → auth.users
- `invite_code` TEXT UNIQUE — 8-character alphanumeric
- `member_id` UUID nullable FK → members — for claiming existing unclaimed member
- `invited_email` TEXT nullable
- `invited_phone` TEXT nullable
- `expires_at` TIMESTAMPTZ — created_at + 24 hours
- `claimed_by_user_id` UUID nullable FK → auth.users
- `claimed_at` TIMESTAMPTZ nullable
- `created_at` TIMESTAMPTZ

### Three invite methods (admin chooses)

1. **Link/Code** — 8-char code, share via any channel. Recipient enters in-app.
2. **Email/Phone** — admin types email or phone. Notification sent to matching user. Code generated for non-users.
3. **QR Code** — invite code rendered as QR. Recipient scans with app camera.

### Join flow

1. New user signs up → household screen → "Join Household" button
2. Enter code / scan QR / tap notification
3. Validate: code exists, not expired, not claimed
4. If invite has `member_id` → claim existing member (inherit bill history)
5. If no `member_id` → create new member linked to user
6. Mark invite claimed, notify admin

### Expiry

- Invite codes expire after 24 hours
- Expired invites show "Expired" in admin's view with option to regenerate

---

## 4. Push Notifications (FCM)

### Setup

- Firebase project linked to Android app (google-services.json)
- `firebase_messaging` + `firebase_core` Flutter packages
- Supabase Edge Function `send-push` triggered by database webhook on `notifications` INSERT

### FCM token lifecycle

1. On app launch after auth → request permission, get token
2. Upsert to `device_tokens` table
3. On token refresh → update row
4. On sign out → delete token row

### Notification messages

| Type | Title | Body example |
|---|---|---|
| `settlement_request` | Settlement Request | "Malook wants to settle 485.25 TL with you" |
| `settlement_confirmed` | Settlement Confirmed | "Zanzooon confirmed your 485.25 TL settlement" |
| `settlement_rejected` | Settlement Rejected | "Zanzooon rejected your 485.25 TL settlement" |
| `admin_bill_delete` | Bill Deleted | "Admin deleted your bill: Groceries (250 TL)" |
| `household_invite` | Household Invite | "Malook invited you to join 'Our Apartment'" |

### On tap

App opens notifications screen, scrolled to relevant notification.

---

## 5. Notifications Screen UI

### Access

Bell icon in home screen app bar with unread badge count.

### Layout

- App bar: "Notifications" title, "Mark all read" button
- List of cards sorted newest first
- Each card: icon (by type), title, body, time ago, unread dot
- Swipeable to dismiss/delete

### Settlement request cards

Two inline action buttons:
- **Confirm** (green)
- **Reject** (red)

### Other types

Informational — tap to navigate to relevant screen.

### Empty state

"No notifications yet" with bell icon.

---

## Architecture Summary

| Component | Approach |
|---|---|
| Notifications | Supabase table + Realtime + FCM push |
| Settlement flow | Pending → Confirmed/Rejected, bill only on confirm |
| Invites | 24h codes via link, email/phone, QR. Admin assigns member or creates new |
| Push | Edge Function triggered on notification insert |
| UI | Dedicated notifications screen with bell + badge |
