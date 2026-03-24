# Login Flow UX Rework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Simplify the app so auth account = member identity. Remove member select screen, local-only mode, and per-member PINs. Add household switcher dropdown and per-account app lock passcode.

**Architecture:** Remove the member selection layer entirely. On login, auto-resolve the current member by matching `members.user_id == auth.uid()` in the active household. Replace per-member PINs with a per-account passcode stored in FlutterSecureStorage. Add a household dropdown in the home screen app bar. Remove the "Continue without account" onboarding option.

**Tech Stack:** Flutter, Provider, Supabase, FlutterSecureStorage, SharedPreferences

---

## Task 1: Remove "Continue without account" from Onboarding

**Files:**
- Modify: `lib/screens/onboarding_screen.dart`

**Step 1: Remove the "Continue without account" TextButton**

Read the file, find the "Continue without account" button, and remove it entirely. Keep only "Get Started" which goes to `/auth`.

**Step 2: Commit**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "feat: remove 'Continue without account' — require auth for all users"
```

---

## Task 2: Auto-resolve Member from Auth in HouseholdProvider

**Files:**
- Modify: `lib/providers/household_provider.dart`

**Step 1: Add method to auto-resolve current member by auth user_id**

Add a new method that, given a household, finds the member where `user_id` matches the current Supabase auth user:

```dart
/// Auto-set currentMember by matching auth user_id to a member in the household
Future<Member?> resolveCurrentMember(String authUserId) async {
  if (_currentHousehold == null) return null;
  // Check cloud members table for user_id match
  try {
    final supabase = Supabase.instance.client;
    final remoteMembers = await supabase
        .from('members')
        .select('id')
        .eq('household_id', _currentHousehold!.remoteId ?? '')
        .eq('user_id', authUserId)
        .maybeSingle();
    if (remoteMembers != null) {
      final remoteId = remoteMembers['id'] as String;
      // Find local member by remote_id
      final match = _members.where((m) => m.remoteId == remoteId).firstOrNull;
      if (match != null) {
        _currentMember = match;
        notifyListeners();
        return match;
      }
    }
  } catch (_) {}
  // Fallback: check local members for matching remote user linkage
  // This handles the case where remote lookup fails
  return null;
}
```

Add import for Supabase at the top of the file.

**Step 2: Add method to get households for current auth user**

```dart
/// Get only households where the current auth user is a member
Future<List<Household>> getHouseholdsForUser(String authUserId) async {
  try {
    final supabase = Supabase.instance.client;
    final memberRows = await supabase
        .from('members')
        .select('household_id')
        .eq('user_id', authUserId);
    final remoteHouseholdIds = memberRows
        .map((r) => r['household_id'] as String)
        .toSet();
    // Filter local households that match
    return _households
        .where((h) => h.remoteId != null && remoteHouseholdIds.contains(h.remoteId))
        .toList();
  } catch (_) {
    return _households; // Fallback to all local
  }
}
```

**Step 3: Commit**

```bash
git add lib/providers/household_provider.dart
git commit -m "feat: add resolveCurrentMember and getHouseholdsForUser methods"
```

---

## Task 3: Update Household Screen — Skip Member Select, Auto-resolve

**Files:**
- Modify: `lib/screens/household_screen.dart`

**Step 1: Change household tap behavior**

Currently tapping a household navigates to `/select-member`. Change it to:
1. Set the current household
2. Call `resolveCurrentMember(authUserId)`
3. If member found → navigate to `/home`
4. If member not found → show error "You're not a member of this household"

Replace:
```dart
Navigator.pushNamed(context, '/select-member');
```
With:
```dart
final authUser = Supabase.instance.client.auth.currentUser;
if (authUser != null) {
  final member = await provider.resolveCurrentMember(authUser.id);
  if (member != null && context.mounted) {
    context.read<BillProvider>().loadBills(provider.currentHousehold!.id!);
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are not a member of this household')),
    );
  }
}
```

**Step 2: Filter households to only show user's households**

Instead of showing all local households, filter by auth user membership. In the build method, get the filtered list and display only those.

**Step 3: Auto-create member when creating household**

When creating a new household, auto-create a member linked to the current auth user:
- After `provider.createHousehold(name, [displayName])`, also sync the household and member to cloud with `user_id` set.

**Step 4: Commit**

```bash
git add lib/screens/household_screen.dart
git commit -m "feat: skip member select, auto-resolve member from auth on household tap"
```

---

## Task 4: Update main.dart — New Launch Flow

**Files:**
- Modify: `lib/main.dart`

**Step 1: Update initial route logic**

Change the home/initialRoute to:
- Not authenticated → `AuthScreen` (not onboarding — go directly to sign in/up)
- Authenticated → `HouseholdScreen` (user picks or auto-enters their household)

Remove the onboarding as the entry point since there's no local-only option anymore.

**Step 2: Remove `/select-member` route**

Remove the route entry for `/select-member` from the routes map.

**Step 3: Save and restore last-used household**

Add logic to check SharedPreferences for `last_household_id`. If it exists and the user is a member, go straight to `/home` skipping the household picker.

```dart
// In main() or in the home widget:
final prefs = await SharedPreferences.getInstance();
final lastHouseholdId = prefs.getInt('last_household_id');
if (lastHouseholdId != null && authUser != null) {
  // Try to restore last household and auto-resolve member
  await householdProvider.setCurrentHousehold(/* find by id */);
  final member = await householdProvider.resolveCurrentMember(authUser.id);
  if (member != null) {
    billProvider.loadBills(lastHouseholdId);
    // Go straight to home
  }
}
```

**Step 4: Save last-used household when entering home**

In the household screen, after navigating to home, save:
```dart
prefs.setInt('last_household_id', household.id!);
```

**Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: new launch flow — auth required, auto-restore last household"
```

---

## Task 5: Household Dropdown Switcher in Home Screen

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Replace "home" title with tappable household name**

Change the app bar title from the static `Text('home')` to a tappable household name with a dropdown arrow:

```dart
GestureDetector(
  onTap: () => _showHouseholdSwitcher(context),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(householdProvider.currentHousehold?.name ?? 'home',
        style: TextStyle(...)),
      Icon(Icons.arrow_drop_down_rounded, ...),
    ],
  ),
),
```

**Step 2: Add `_showHouseholdSwitcher` method**

Shows a bottom sheet or dropdown with the user's households. On tap, switches household, resolves member, reloads bills:

```dart
void _showHouseholdSwitcher(BuildContext context) {
  final householdProvider = context.read<HouseholdProvider>();
  final authUser = Supabase.instance.client.auth.currentUser;
  // Show bottom sheet with household list
  // On tap: switch household, resolve member, reload
}
```

**Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: household dropdown switcher in home screen app bar"
```

---

## Task 6: Per-Account Passcode (App Lock)

**Files:**
- Create: `lib/screens/passcode_screen.dart`
- Create: `lib/services/passcode_service.dart`
- Modify: `lib/main.dart`
- Modify: `lib/screens/settings_screen.dart`

**Step 1: Create PasscodeService**

Uses FlutterSecureStorage to store/verify a 4-digit passcode per auth user:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasscodeService {
  final _storage = const FlutterSecureStorage();

  String _key(String userId) => 'passcode_$userId';

  Future<bool> hasPasscode(String userId) async {
    final value = await _storage.read(key: _key(userId));
    return value != null && value.isNotEmpty;
  }

  Future<void> setPasscode(String userId, String passcode) async {
    await _storage.write(key: _key(userId), value: passcode);
  }

  Future<bool> verifyPasscode(String userId, String passcode) async {
    final stored = await _storage.read(key: _key(userId));
    return stored == passcode;
  }

  Future<void> removePasscode(String userId) async {
    await _storage.delete(key: _key(userId));
  }
}
```

**Step 2: Create PasscodeScreen**

A full-screen 4-digit PIN entry (similar to current PIN dialog but as a standalone screen):
- Shows 4 dots that fill as digits are entered
- Number pad
- On correct entry → navigate to household screen or home
- On wrong entry → shake animation, clear dots

**Step 3: Wire passcode into launch flow in main.dart**

After auth check, before entering the app:
```dart
if (authUser != null) {
  final hasPasscode = await passcodeService.hasPasscode(authUser.id);
  if (hasPasscode) {
    // Show PasscodeScreen first, which navigates to home on success
  }
}
```

**Step 4: Update Settings — replace PIN section with App Lock**

Remove the per-member PIN UI. Replace with:
- "App Lock" toggle
- If enabled: "Change Passcode" button
- If disabled: tapping toggle prompts to set passcode

**Step 5: Commit**

```bash
git add lib/services/passcode_service.dart lib/screens/passcode_screen.dart lib/main.dart lib/screens/settings_screen.dart
git commit -m "feat: per-account passcode app lock replacing per-member PINs"
```

---

## Task 7: Clean Up — Remove Dead Code

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/settings_screen.dart`
- Delete or leave: `lib/screens/member_select_screen.dart` (remove import/route, can delete file)
- Delete or leave: `lib/services/pin_helper.dart` (remove imports, can delete file)

**Step 1: Remove member_select_screen route and import from main.dart**

**Step 2: Remove PIN-related code from settings_screen.dart**

Remove the entire PIN management section (the `_setPinDialog`, `_removePin` methods, and the PIN row in the UI). Replace with the App Lock section from Task 6.

**Step 3: Remove PinHelper imports from any file that still references it**

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

Fix any issues.

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove member select screen, PIN system, dead code"
```

---

## Task 8: Auto-create Member on Household Creation

**Files:**
- Modify: `lib/screens/household_screen.dart`
- Modify: `lib/providers/household_provider.dart`

**Step 1: When creating a household, auto-link the creator as a member**

After creating the household locally, sync it to Supabase and create a member with `user_id` set to the current auth user:

```dart
// After local household creation:
final authUser = Supabase.instance.client.auth.currentUser;
if (authUser != null) {
  // Sync household to cloud
  final uuid = Uuid().v4();
  await Supabase.instance.client.from('households').upsert({...});
  // Update local remote_id
  // Create member in cloud with user_id
  await Supabase.instance.client.from('members').insert({
    'household_id': householdRemoteId,
    'user_id': authUser.id,
    'name': displayName,
    'is_admin': true,
  });
  // Update local member remote_id
}
```

**Step 2: Commit**

```bash
git add lib/screens/household_screen.dart lib/providers/household_provider.dart
git commit -m "feat: auto-create and cloud-link member on household creation"
```

---

## Task 9: Final Polish and Integration

**Files:**
- Various

**Step 1: Run flutter analyze**

```bash
flutter analyze
```

Fix all issues.

**Step 2: Test the full flow**

1. Fresh start: auth screen → sign up → create household → straight to home
2. Reopen app → straight to home (last household restored)
3. Household switcher dropdown works
4. Settings: app lock toggle works
5. Sign out → back to auth screen

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: login flow rework complete — auth=member, household switcher, app lock"
```
