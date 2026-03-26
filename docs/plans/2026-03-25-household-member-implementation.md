# Household & Member Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign household creation and member linking so every member is a real auth user, notifications are household-scoped, and the startup flow is clean.

**Architecture:** Remove name-based member creation. Household creation = name + currency only, auto-creates one admin member linked to auth user. Others join via invite codes. Notifications filter by current household. Passcode and onboarding removed.

**Tech Stack:** Flutter, Provider, SQLite (sqflite), Supabase (auth, RLS, realtime)

---

### Task 1: Clean up Member model — remove `pin`

**Files:**
- Modify: `lib/models/member.dart`

**Step 1:** Remove `pin` field, its constructor parameter, its `toMap()` entry, and its `fromMap()` entry.

```dart
class Member {
  final int? id;
  final int householdId;
  final String name;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;
  final String? remoteId;
  final String? updatedAt;
  final String? userId;

  Member({
    this.id,
    required this.householdId,
    required this.name,
    this.isActive = true,
    this.isAdmin = false,
    DateTime? createdAt,
    this.remoteId,
    this.updatedAt,
    this.userId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'is_admin': isAdmin ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'remote_id': remoteId,
      'updated_at': updatedAt,
      'user_id': userId,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      name: map['name'] as String,
      isActive: (map['is_active'] as int?) != 0,
      isAdmin: (map['is_admin'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime(2020),
      remoteId: map['remote_id'] as String?,
      updatedAt: map['updated_at'] as String?,
      userId: map['user_id'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

**Step 2:** Run `flutter analyze` — expected: clean (pin column still exists in SQLite, just not read).

**Step 3:** Commit: `refactor: remove pin field from Member model`

---

### Task 2: Remove passcode screen, service, and onboarding route

**Files:**
- Delete: `lib/screens/passcode_screen.dart`
- Delete: `lib/services/passcode_service.dart`
- Modify: `lib/screens/launch_screen.dart` — remove commented passcode imports/code
- Modify: `lib/screens/settings_screen.dart` — remove passcode import, `_showPasscodeSetup()`, and the passcode settings tile
- Modify: `lib/main.dart` — remove onboarding import and `/onboarding` route
- Modify: `lib/screens/settings_screen.dart:1035` — change sign-out navigation from `/onboarding` to `/auth`

**Step 1:** Delete passcode files.

**Step 2:** In `launch_screen.dart`, remove lines 7-9 (commented imports) and lines 33-37 (commented passcode check). The `_route()` method becomes:

```dart
Future<void> _route() async {
  final authUser = Supabase.instance.client.auth.currentUser;
  if (authUser == null) {
    if (mounted) Navigator.pushReplacementNamed(context, '/auth');
    return;
  }
  await _navigateAfterAuth(authUser);
}
```

**Step 3:** In `settings_screen.dart`:
- Remove `import '../services/passcode_service.dart';`
- Remove the entire `_showPasscodeSetup()` method (lines ~37-165)
- Remove the passcode settings tile that calls it (line ~396)
- Change sign-out navigation (line ~1035) from `'/onboarding'` to `'/auth'`

**Step 4:** In `main.dart`:
- Remove `import 'screens/onboarding_screen.dart';` (line 26)
- Remove `'/onboarding': (context) => const OnboardingScreen(),` (line 455)

**Step 5:** Run `flutter analyze` — expected: clean.

**Step 6:** Commit: `refactor: remove passcode screen/service and onboarding route`

---

### Task 3: Rewrite `resolveCurrentMember()` — simple user_id lookup

**Files:**
- Modify: `lib/providers/household_provider.dart`

**Step 1:** Replace the entire `resolveCurrentMember()` method and remove `_persistMemberLink()` and `getHouseholdsForUser()`. The new version:

```dart
/// Resolve which member the current auth user is in the active household.
/// Local user_id lookup first, cloud fallback for first-time sync.
Future<Member?> resolveCurrentMember(String authUserId) async {
  if (_currentHousehold == null) return null;

  // Strategy 1: Local lookup by user_id (instant, works offline)
  var match = _members.where((m) => m.userId == authUserId).firstOrNull;
  if (match != null) {
    _currentMember = match;
    notifyListeners();
    return match;
  }

  // Strategy 2: Cloud lookup (first-time on new device)
  try {
    final supabase = Supabase.instance.client;
    final remoteHouseholdId = _currentHousehold!.remoteId;
    if (remoteHouseholdId != null && remoteHouseholdId.length > 8) {
      final remoteMember = await supabase
          .from('members')
          .select('id, name')
          .eq('household_id', remoteHouseholdId)
          .eq('user_id', authUserId)
          .maybeSingle();
      if (remoteMember != null) {
        final remoteId = remoteMember['id'] as String;
        final remoteName = remoteMember['name'] as String?;
        match = _members.where((m) => m.remoteId == remoteId).firstOrNull;
        match ??= _members.where((m) =>
            remoteName != null && m.name.toLowerCase() == remoteName.toLowerCase()
        ).firstOrNull;

        // Create local member if exists on cloud but not locally
        if (match == null && remoteName != null) {
          final db = await _db.database;
          final newId = await db.insert('members', {
            'household_id': _currentHousehold!.id,
            'name': remoteName,
            'is_active': 1,
            'is_admin': 0,
            'remote_id': remoteId,
            'user_id': authUserId,
            'created_at': DateTime.now().toIso8601String(),
          });
          _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
          match = _members.where((m) => m.id == newId).firstOrNull;
        }

        if (match != null) {
          _currentMember = match;
          notifyListeners();
          // Persist user_id locally if missing
          if (match.userId != authUserId) {
            try {
              final db = await _db.database;
              final updates = <String, dynamic>{'user_id': authUserId};
              if (match.remoteId != remoteId) updates['remote_id'] = remoteId;
              await db.update('members', updates, where: 'id = ?', whereArgs: [match.id]);
              _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
            } catch (_) {}
          }
          return match;
        }
      }
    }
  } catch (_) {}

  return null;
}
```

**Step 2:** Remove the `_persistMemberLink()` method entirely.

**Step 3:** Remove the `getHouseholdsForUser()` method entirely.

**Step 4:** Run `flutter analyze` — fix any references to removed methods.

**Step 5:** Commit: `refactor: simplify resolveCurrentMember to user_id lookup`

---

### Task 4: Rewrite household creation — name only, auto-member

**Files:**
- Modify: `lib/screens/household_screen.dart`
- Modify: `lib/providers/household_provider.dart`
- Modify: `lib/database/database_helper.dart`

**Step 1:** In `household_provider.dart`, replace `createHousehold()` with a new version that takes the auth user's info:

```dart
/// Create a household with the current user as the sole admin member.
Future<Household> createHouseholdForUser(String name, String userId, String displayName) async {
  final db = await _db.database;
  late int householdId;
  late int memberId;
  await db.transaction((txn) async {
    householdId = await txn.insert('households', Household(name: name).toMap());
    final member = Member(
      householdId: householdId,
      name: displayName,
      isAdmin: true,
      userId: userId,
    );
    memberId = await txn.insert('members', member.toMap());
  });
  await loadHouseholds();
  return _households.firstWhere((h) => h.id == householdId);
}
```

**Step 2:** In `household_screen.dart`, rewrite `_showCreateSheet()`:
- Remove ALL member name TextEditingController fields
- Remove "Add Member" button
- Remove member name TextFields
- Change validation from `memberNames.length < 2` to just `name.isEmpty`
- On submit: call `provider.createHouseholdForUser(name, authUser.id, displayName)`
- Then sync to cloud, set as current household, navigate to `/home`

**Step 3:** Remove the entire `_syncUnsyncedHouseholds()` method from `household_screen.dart`.

**Step 4:** Update `_loadHouseholds()` to just load all local households (no sync, no filter):

```dart
Future<void> _loadHouseholds() async {
  final provider = context.read<HouseholdProvider>();
  await provider.loadHouseholds();
  if (mounted) setState(() { _userHouseholds = provider.households; _loading = false; });
}
```

**Step 5:** Run `flutter analyze` — expected: clean.

**Step 6:** Commit: `feat: household creation with auto-member, remove multi-member creation`

---

### Task 5: Rewrite HouseholdScreen UI — "Create" or "Join" choice

**Files:**
- Modify: `lib/screens/household_screen.dart`

**Step 1:** Rewrite `_buildEmptyState()` to show two buttons:
- "Create Household" — opens the simplified create sheet (name only)
- "Join Household" — navigates to `/join-household` (existing invite code screen)

Remove the duplicate "Join Household" button that was in the top bar area (lines ~152-169). The empty state is now the primary entry point.

**Step 2:** Keep `_buildHouseholdList()` as-is for users who already have households.

**Step 3:** Run `flutter analyze` — expected: clean.

**Step 4:** Commit: `feat: household screen shows Create or Join for empty state`

---

### Task 6: Fix auth success navigation

**Files:**
- Modify: `lib/screens/auth_screen.dart`

**Step 1:** The `_navigateAfterAuth()` method already exists from earlier work. Verify it:
- Checks SharedPreferences for `last_household_id`
- If valid household + member resolves → `/home`
- Otherwise → `/households`

This should already work correctly with the new simplified `resolveCurrentMember()`.

**Step 2:** Run `flutter analyze` — expected: clean.

**Step 3:** Commit (if changes needed): `fix: auth success navigation uses household gate`

---

### Task 7: Scope notifications to current household

**Files:**
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/screens/home_screen.dart` (where notifications are loaded)

**Step 1:** Change `loadNotifications()` to accept a household ID:

```dart
Future<void> loadNotifications({String? householdId}) async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return;
  try {
    var query = _client
        .from('notifications')
        .select()
        .eq('recipient_user_id', userId);
    if (householdId != null) {
      query = query.eq('household_id', householdId);
    }
    _notifications = await query
        .order('created_at', ascending: false)
        .limit(50);
    _unreadCount = _notifications.where((n) => n['read'] == false).length;
    notifyListeners();
  } catch (e) {
    debugPrint('Failed to load notifications: $e');
  }
}
```

**Step 2:** Update `markAllAsRead()` to also scope by household:

```dart
Future<void> markAllAsRead({String? householdId}) async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return;
  var query = _client
      .from('notifications')
      .update({'read': true})
      .eq('recipient_user_id', userId)
      .eq('read', false);
  if (householdId != null) {
    query = query.eq('household_id', householdId);
  }
  await query;
  for (int i = 0; i < _notifications.length; i++) {
    _notifications[i] = {..._notifications[i], 'read': true};
  }
  _unreadCount = 0;
  notifyListeners();
}
```

**Step 3:** In `home_screen.dart`, pass the household's remote ID when loading notifications:

```dart
final householdRemoteId = context.read<HouseholdProvider>().currentHousehold?.remoteId;
notifService.loadNotifications(householdId: householdRemoteId);
```

**Step 4:** Run `flutter analyze` — expected: clean.

**Step 5:** Commit: `feat: scope notifications to current household`

---

### Task 8: Clean up DatabaseHelper — remove old createHouseholdWithMembers

**Files:**
- Modify: `lib/database/database_helper.dart`
- Modify: `lib/database/data_repository.dart` (if it defines the interface)

**Step 1:** Remove `createHouseholdWithMembers()` method from `database_helper.dart`. It's replaced by `HouseholdProvider.createHouseholdForUser()`.

**Step 2:** Remove `updateMemberPin()` method (pin is removed).

**Step 3:** Update `data_repository.dart` interface if it references these methods.

**Step 4:** Run `flutter analyze` — fix any remaining references.

**Step 5:** Commit: `refactor: remove old multi-member creation and pin methods from DB`

---

### Task 9: Final verification

**Step 1:** Run `flutter analyze` — must be clean.

**Step 2:** Test the full flow manually:
- Fresh app launch → auth screen
- Sign up → household picker (empty state with Create/Join)
- Create household "Home" → auto-enters HomeScreen as admin member
- Check notifications badge → 0 (scoped to this household)
- Sign out → auth screen
- Sign in again → goes directly to HomeScreen (last household restored)

**Step 3:** Commit any final fixes.

**Step 4:** Final commit: `feat: complete household-member redesign`
