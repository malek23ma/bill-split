# Phase 5b Implementation Plan — Social Features

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add settlement confirmation flow (pending → confirmed/rejected), push notifications via FCM, and household invites (code, email/phone, QR) so users on separate devices can interact in real time.

**Architecture:** New Supabase tables for settlements, notifications, device_tokens, and household_invites. Supabase Realtime subscriptions for in-app updates. Firebase Cloud Messaging for push notifications via a Supabase Edge Function. Settlement "Pay" buttons create pending records instead of immediate bills — bills only created on receiver confirmation.

**Tech Stack:** Flutter, Supabase (Realtime, Edge Functions), Firebase (firebase_messaging, firebase_core), qr_flutter, mobile_scanner

---

## Task 1: Add Firebase and QR Dependencies

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add dependencies**

Under `dependencies:`, add:

```yaml
firebase_core: ^3.8.0
firebase_messaging: ^15.2.0
qr_flutter: ^4.1.0
mobile_scanner: ^6.0.0
```

**Step 2: Run flutter pub get**

```bash
flutter pub get
```

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add Firebase, QR code dependencies"
```

---

## Task 2: Supabase Schema — New Tables for Phase 5b

**Files:**
- Create: `supabase/migrations/003_phase5b_tables.sql`

**Step 1: Create migration file**

```sql
-- Settlements (pending confirmation flow)
CREATE TABLE settlements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  from_member_id UUID NOT NULL REFERENCES members(id),
  to_member_id UUID NOT NULL REFERENCES members(id),
  amount DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_by_user_id UUID NOT NULL REFERENCES auth.users(id),
  confirmed_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID REFERENCES households(id) ON DELETE CASCADE,
  recipient_user_id UUID NOT NULL REFERENCES auth.users(id),
  sender_user_id UUID REFERENCES auth.users(id),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Device tokens for FCM push
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, device_id)
);

-- Household invites
CREATE TABLE household_invites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  invited_by_user_id UUID NOT NULL REFERENCES auth.users(id),
  invite_code TEXT NOT NULL UNIQUE,
  member_id UUID REFERENCES members(id),
  invited_email TEXT,
  invited_phone TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  claimed_by_user_id UUID REFERENCES auth.users(id),
  claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Triggers for updated_at
CREATE TRIGGER settlements_updated_at BEFORE UPDATE ON settlements FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_invites ENABLE ROW LEVEL SECURITY;

-- Settlements: household members can read, involved parties can update
CREATE POLICY "Members can read settlements" ON settlements FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Members can create settlements" ON settlements FOR INSERT WITH CHECK (is_household_member(household_id));
CREATE POLICY "Members can update settlements" ON settlements FOR UPDATE USING (is_household_member(household_id));

-- Notifications: users can read/update their own
CREATE POLICY "Users can read own notifications" ON notifications FOR SELECT USING (auth.uid() = recipient_user_id);
CREATE POLICY "Users can insert notifications" ON notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (auth.uid() = recipient_user_id);
CREATE POLICY "Users can delete own notifications" ON notifications FOR DELETE USING (auth.uid() = recipient_user_id);

-- Device tokens: users manage their own
CREATE POLICY "Users can manage own tokens" ON device_tokens FOR ALL USING (auth.uid() = user_id);

-- Household invites: admin can create, anyone can read by code
CREATE POLICY "Admin can manage invites" ON household_invites FOR ALL USING (
  is_household_admin(household_id) OR claimed_by_user_id = auth.uid()
);
CREATE POLICY "Anyone can read invite by code" ON household_invites FOR SELECT USING (auth.uid() IS NOT NULL);
```

**Step 2: Commit**

```bash
git add supabase/migrations/003_phase5b_tables.sql
git commit -m "feat: Supabase schema for settlements, notifications, invites, device_tokens"
```

---

## Task 3: Settlement Service

**Files:**
- Create: `lib/services/settlement_service.dart`

**Step 1: Create SettlementService**

Handles creating pending settlements, confirming, and rejecting. Talks to Supabase directly.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SettlementService {
  final SupabaseClient _client;

  SettlementService(this._client);

  /// Create a pending settlement request
  Future<Map<String, dynamic>> createSettlement({
    required String householdId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final result = await _client.from('settlements').insert({
      'household_id': householdId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'status': 'pending',
      'created_by_user_id': userId,
    }).select().single();
    return result;
  }

  /// Confirm a pending settlement
  Future<void> confirmSettlement(String settlementId) async {
    await _client.from('settlements').update({
      'status': 'confirmed',
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', settlementId);
  }

  /// Reject a pending settlement
  Future<void> rejectSettlement(String settlementId) async {
    await _client.from('settlements').update({
      'status': 'rejected',
      'rejected_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', settlementId);
  }

  /// Get pending settlements for a household
  Future<List<Map<String, dynamic>>> getPendingSettlements(String householdId) async {
    return await _client
        .from('settlements')
        .select()
        .eq('household_id', householdId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  /// Get all settlements for a household
  Future<List<Map<String, dynamic>>> getSettlements(String householdId) async {
    return await _client
        .from('settlements')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/settlement_service.dart
git commit -m "feat: SettlementService with create, confirm, reject"
```

---

## Task 4: Notification Service

**Files:**
- Create: `lib/services/notification_service.dart`

**Step 1: Create NotificationService**

Handles CRUD for notifications, Realtime subscription, and sending notifications.

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService extends ChangeNotifier {
  final SupabaseClient _client;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  RealtimeChannel? _channel;

  NotificationService(this._client);

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  /// Load notifications for current user
  Future<void> loadNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _notifications = await _client
        .from('notifications')
        .select()
        .eq('recipient_user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    _unreadCount = _notifications.where((n) => n['read'] == false).length;
    notifyListeners();
  }

  /// Subscribe to realtime notifications
  void subscribeToRealtime() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _channel = _client.channel('notifications:$userId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: (payload) {
            final newNotification = payload.newRecord;
            _notifications.insert(0, newNotification);
            _unreadCount++;
            notifyListeners();
          },
        )
        .subscribe();
  }

  /// Unsubscribe from realtime
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Send a notification (insert into table)
  Future<void> sendNotification({
    String? householdId,
    required String recipientUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    await _client.from('notifications').insert({
      'household_id': householdId,
      'recipient_user_id': recipientUserId,
      'sender_user_id': senderId,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
    });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _client.from('notifications').update({'read': true}).eq('id', notificationId);
    final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (idx != -1 && _notifications[idx]['read'] == false) {
      _notifications[idx] = {..._notifications[idx], 'read': true};
      _unreadCount--;
      notifyListeners();
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('notifications').update({'read': true})
        .eq('recipient_user_id', userId)
        .eq('read', false);
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = {..._notifications[i], 'read': true};
    }
    _unreadCount = 0;
    notifyListeners();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
    _notifications.removeWhere((n) => n['id'] == notificationId);
    _unreadCount = _notifications.where((n) => n['read'] == false).length;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: NotificationService with Realtime subscription and CRUD"
```

---

## Task 5: FCM Push Notification Setup

**Files:**
- Create: `lib/services/push_notification_service.dart`
- Modify: `lib/main.dart`

**Step 1: Create PushNotificationService**

Handles FCM token registration, permission requests, and foreground message handling.

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final SupabaseClient _client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  PushNotificationService(this._client);

  /// Initialize: request permission, register token
  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _registerToken();
      _messaging.onTokenRefresh.listen(_saveToken);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      // NotificationService handles in-app display via Realtime
    });

    // Handle background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM tap: ${message.data}');
      // Navigation handled by app
    });
  }

  Future<void> _registerToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('sync_device_id') ?? 'unknown';

    await _client.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'device_id': deviceId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,device_id');
  }

  /// Remove token on sign out
  Future<void> removeToken() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('sync_device_id') ?? 'unknown';
    await _client.from('device_tokens').delete()
        .eq('user_id', userId)
        .eq('device_id', deviceId);
  }
}
```

**Step 2: Initialize Firebase in main.dart**

Add `import 'package:firebase_core/firebase_core.dart';` and initialize before Supabase:

```dart
await Firebase.initializeApp();
```

Create `PushNotificationService` after auth, and call `init()` if authenticated.

**Step 3: Commit**

```bash
git add lib/services/push_notification_service.dart lib/main.dart
git commit -m "feat: FCM push notification service with token registration"
```

---

## Task 6: Supabase Edge Function — send-push

**Files:**
- Create: `supabase/functions/send-push/index.ts`

**Step 1: Create Edge Function**

This function is called via a Supabase Database Webhook when a row is inserted into `notifications`. It looks up the recipient's FCM tokens and sends a push via the FCM HTTP API.

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const fcmServerKey = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req) => {
  try {
    const payload = await req.json();
    const notification = payload.record;

    if (!notification || !notification.recipient_user_id) {
      return new Response("No recipient", { status: 400 });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get recipient's FCM tokens
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("fcm_token")
      .eq("user_id", notification.recipient_user_id);

    if (!tokens || tokens.length === 0) {
      return new Response("No tokens", { status: 200 });
    }

    // Send FCM push to each token
    for (const { fcm_token } of tokens) {
      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify({
          to: fcm_token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            type: notification.type,
            notification_id: notification.id,
            ...(notification.data || {}),
          },
        }),
      });
    }

    return new Response("Sent", { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
```

**Step 2: Commit**

```bash
git add supabase/functions/send-push/index.ts
git commit -m "feat: Edge Function to send FCM pushes on notification insert"
```

**Note:** After committing, deploy via `supabase functions deploy send-push` and create a Database Webhook in the Supabase dashboard pointing to this function on `notifications` INSERT.

---

## Task 7: Invite Service

**Files:**
- Create: `lib/services/invite_service.dart`

**Step 1: Create InviteService**

```dart
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteService {
  final SupabaseClient _client;
  static final _random = Random.secure();

  InviteService(this._client);

  /// Generate an 8-char alphanumeric code
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Create an invite
  Future<Map<String, dynamic>> createInvite({
    required String householdId,
    String? memberId, // existing unclaimed member to link
    String? email,
    String? phone,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final code = _generateCode();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));

    final result = await _client.from('household_invites').insert({
      'household_id': householdId,
      'invited_by_user_id': userId,
      'invite_code': code,
      'member_id': memberId,
      'invited_email': email,
      'invited_phone': phone,
      'expires_at': expiresAt.toIso8601String(),
    }).select().single();

    return result;
  }

  /// Look up an invite by code
  Future<Map<String, dynamic>?> getInviteByCode(String code) async {
    final result = await _client
        .from('household_invites')
        .select('*, households(name)')
        .eq('invite_code', code.toUpperCase())
        .isFilter('claimed_by_user_id', null)
        .maybeSingle();
    return result;
  }

  /// Claim an invite (join the household)
  Future<bool> claimInvite(String inviteId) async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now().toUtc();

    // Get the invite
    final invite = await _client.from('household_invites')
        .select()
        .eq('id', inviteId)
        .single();

    // Check expiry
    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (now.isAfter(expiresAt)) return false;

    // Check not already claimed
    if (invite['claimed_by_user_id'] != null) return false;

    final householdId = invite['household_id'] as String;
    final memberId = invite['member_id'] as String?;

    if (memberId != null) {
      // Claim existing member — link user_id
      await _client.from('members').update({
        'user_id': userId,
      }).eq('id', memberId);
    } else {
      // Create new member linked to this user
      final profile = await _client.from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final name = profile?['display_name'] ?? 'New Member';
      await _client.from('members').insert({
        'household_id': householdId,
        'user_id': userId,
        'name': name,
      });
    }

    // Mark invite as claimed
    await _client.from('household_invites').update({
      'claimed_by_user_id': userId,
      'claimed_at': now.toIso8601String(),
    }).eq('id', inviteId);

    return true;
  }

  /// Get active invites for a household (admin view)
  Future<List<Map<String, dynamic>>> getHouseholdInvites(String householdId) async {
    return await _client
        .from('household_invites')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);
  }

  /// Revoke/delete an invite
  Future<void> revokeInvite(String inviteId) async {
    await _client.from('household_invites').delete().eq('id', inviteId);
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/invite_service.dart
git commit -m "feat: InviteService with create, claim, code lookup, revoke"
```

---

## Task 8: Notifications Screen UI

**Files:**
- Create: `lib/screens/notifications_screen.dart`

**Step 1: Create NotificationsScreen**

Read `lib/constants.dart` for styling constants (AppColors, AppScale, AppRadius).

A `StatefulWidget` that:
- Loads notifications from `NotificationService` on init
- Shows a list of notification cards sorted newest first
- Each card: icon (based on type), title, body, relative time, unread dot
- Settlement request cards have inline Confirm/Reject buttons
- Swipe to dismiss (delete notification)
- "Mark all read" button in app bar
- Empty state: bell icon + "No notifications yet"
- Uses app styling: isDark, AppColors, AppScale

Settlement request card actions:
- Confirm: calls `SettlementService.confirmSettlement()`, sends confirmation notification, then creates a settlement bill via `BillProvider.settleUp()`
- Reject: calls `SettlementService.rejectSettlement()`, sends rejection notification

**Step 2: Commit**

```bash
git add lib/screens/notifications_screen.dart
git commit -m "feat: notifications screen with settlement confirm/reject actions"
```

---

## Task 9: Invite Screen UI

**Files:**
- Create: `lib/screens/invite_screen.dart`
- Create: `lib/screens/join_household_screen.dart`

**Step 1: Create InviteScreen (admin creates invites)**

Accessible from SettingsScreen. Shows:
- Three method tabs/buttons: Code, Email/Phone, QR
- **Code tab:** generates code, shows it large with a copy button and share button
- **Email/Phone tab:** text field for email or phone, sends invite
- **QR tab:** generates QR code from invite code using `qr_flutter`
- Option to assign to existing unclaimed member (dropdown of members without `user_id`)
- List of active/expired invites at the bottom with revoke option

**Step 2: Create JoinHouseholdScreen (new user joins)**

Accessible from HouseholdScreen ("Join Household" button). Shows:
- Text field to enter 8-char code
- "Scan QR" button that opens camera via `mobile_scanner`
- On valid code: shows household name, member slot info, "Join" button
- On expired/invalid: error message

**Step 3: Commit**

```bash
git add lib/screens/invite_screen.dart lib/screens/join_household_screen.dart
git commit -m "feat: invite creation and join household screens"
```

---

## Task 10: Wire Settlement Flow Into Existing UI

**Files:**
- Modify: `lib/widgets/settle_all_sheet.dart`
- Modify: `lib/widgets/balance_card.dart`
- Modify: `lib/screens/home_screen.dart`

**Step 1: Update "Pay" buttons in SettleAllSheet**

Change the `onSettle` callback. When authenticated, instead of calling `billProvider.settleUp()` directly, call `SettlementService.createSettlement()` to create a pending settlement. Then send a `settlement_request` notification to the receiver.

When not authenticated (local-only mode), keep the existing immediate settlement behavior.

**Step 2: Update "Settle Up" buttons in BalanceCard**

Same change — authenticated users create pending settlements, local-only users settle immediately.

**Step 3: Update HomeScreen `_confirmSettleUp`**

Modify the confirmation dialog to explain that a settlement request will be sent (not immediately applied). Change dialog text from "Settle X with Y?" to "Send settlement request of X to Y?"

**Step 4: Commit**

```bash
git add lib/widgets/settle_all_sheet.dart lib/widgets/balance_card.dart lib/screens/home_screen.dart
git commit -m "feat: Pay buttons create pending settlements when authenticated"
```

---

## Task 11: Notification Bell Icon on HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Add bell icon with unread badge**

In the app bar `actions` list, add a bell icon button (before the sync indicator):

```dart
Builder(
  builder: (context) {
    final notificationService = context.watch<NotificationService>();
    final unread = notificationService.unreadCount;
    return IconButton(
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: Icon(Icons.notifications_outlined, ...),
      ),
      onPressed: () => Navigator.pushNamed(context, '/notifications'),
    );
  },
),
```

**Step 2: Add route in main.dart**

Add `/notifications` route pointing to `NotificationsScreen`.

**Step 3: Commit**

```bash
git add lib/screens/home_screen.dart lib/main.dart
git commit -m "feat: notification bell icon with unread badge on home screen"
```

---

## Task 12: Add Invite Button to HouseholdScreen and SettingsScreen

**Files:**
- Modify: `lib/screens/household_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart`

**Step 1: Add "Join Household" button to HouseholdScreen**

Below the existing "Create Household" button, add a "Join Household" button (only visible when authenticated):

```dart
if (authProvider.isAuthenticated)
  OutlinedButton.icon(
    onPressed: () => Navigator.pushNamed(context, '/join-household'),
    icon: Icon(Icons.group_add_rounded),
    label: Text('Join Household'),
  ),
```

**Step 2: Add "Invite Members" option to SettingsScreen**

In the household section, add a list tile (only for admins):

```dart
if (currentMember.isAdmin)
  ListTile(
    leading: Icon(Icons.person_add_rounded, color: AppColors.primary),
    title: Text('Invite Members'),
    trailing: Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.pushNamed(context, '/invite'),
  ),
```

**Step 3: Add routes in main.dart**

```dart
'/invite': (context) => const InviteScreen(),
'/join-household': (context) => const JoinHouseholdScreen(),
```

**Step 4: Commit**

```bash
git add lib/screens/household_screen.dart lib/screens/settings_screen.dart lib/main.dart
git commit -m "feat: join household and invite members buttons"
```

---

## Task 13: Wire All Services in main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Create and register all new services**

After existing service creation, add:

```dart
final settlementService = SettlementService(Supabase.instance.client);
final notificationService = NotificationService(Supabase.instance.client);
final inviteService = InviteService(Supabase.instance.client);
final pushService = PushNotificationService(Supabase.instance.client);

// Initialize push if authenticated
if (Supabase.instance.client.auth.currentUser != null) {
  await pushService.init();
  notificationService.loadNotifications();
  notificationService.subscribeToRealtime();
}
```

Add to MultiProvider:
```dart
Provider.value(value: settlementService),
ChangeNotifierProvider.value(value: notificationService),
Provider.value(value: inviteService),
Provider.value(value: pushService),
```

Add imports for all new services and screens.

**Step 2: Handle sign out cleanup**

In auth sign-out flow, call `pushService.removeToken()` and `notificationService.unsubscribe()`.

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire settlement, notification, invite, push services into app"
```

---

## Task 14: Admin Bill Delete Notification

**Files:**
- Modify: `lib/screens/bill_detail_screen.dart`
- Modify: `lib/screens/home_screen.dart`

**Step 1: Send notification when admin deletes another member's bill**

In `BillDetailScreen` and `HomeScreen`, when an admin deletes a bill where `bill.paidByMemberId != currentMember.id`:
- Look up the payer member's `user_id`
- Send an `admin_bill_delete` notification via `NotificationService.sendNotification()`
- Include bill details (category, amount) in the notification body

**Step 2: Commit**

```bash
git add lib/screens/bill_detail_screen.dart lib/screens/home_screen.dart
git commit -m "feat: notify payer when admin deletes their bill"
```

---

## Task 15: Final Integration and Polish

**Files:**
- Various

**Step 1: Run flutter analyze**

```bash
flutter analyze
```

Fix any issues.

**Step 2: Verify navigation**

Ensure all new routes work:
- `/notifications` — notifications screen
- `/invite` — invite creation screen
- `/join-household` — join household screen

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: Phase 5b complete — settlements, notifications, invites, push"
```
