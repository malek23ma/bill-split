# Phase 5a Implementation Plan — Cloud Foundation (Supabase)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Supabase cloud sync with real user auth, offline-capable sync, bill deletion permissions, receipt photo upload, and local data migration — while keeping the app fully functional offline.

**Architecture:** Repository pattern with `SupabaseRepository` mirroring `DatabaseHelper`'s API. Local SQLite remains the read source. A `SyncService` queues writes and reconciles local ↔ cloud via `updated_at` timestamps (last write wins). Providers are injected with a `DataRepository` interface.

**Tech Stack:** Flutter, Supabase (supabase_flutter), Provider, sqflite, connectivity_plus, flutter_image_compress, google_sign_in, sign_in_with_apple

---

## Task 1: Add Supabase Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/config/supabase_config.dart`

**Step 1: Add dependencies to pubspec.yaml**

Under `dependencies:`, add:

```yaml
supabase_flutter: ^2.8.0
connectivity_plus: ^6.1.0
flutter_image_compress: ^2.3.0
google_sign_in: ^6.2.2
sign_in_with_apple: ^7.0.1
uuid: ^4.5.1
```

**Step 2: Run flutter pub get**

```bash
flutter pub get
```

**Step 3: Create Supabase config file**

Create `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String receiptsBucket = 'receipts';
}
```

**Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/config/supabase_config.dart
git commit -m "chore: add Supabase and cloud sync dependencies"
```

---

## Task 2: Supabase Project Setup — SQL Schema

**Files:**
- Create: `supabase/migrations/001_initial_schema.sql`

**Step 1: Create the migration file**

This file is applied via the Supabase dashboard or CLI. It creates all cloud tables.

```sql
-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles (linked to auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Households
CREATE TABLE households (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'TRY',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Members
CREATE TABLE members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  pin TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Bills
CREATE TABLE bills (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  entered_by_member_id UUID NOT NULL REFERENCES members(id),
  paid_by_member_id UUID NOT NULL REFERENCES members(id),
  bill_type TEXT NOT NULL,
  total_amount DOUBLE PRECISION NOT NULL,
  photo_path TEXT,
  photo_url TEXT,
  bill_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by_user_id UUID REFERENCES auth.users(id),
  category TEXT NOT NULL DEFAULT 'other',
  recurring_bill_id UUID REFERENCES recurring_bills(id),
  receiver_member_id UUID REFERENCES members(id)
);

-- Bill Items
CREATE TABLE bill_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bill_id UUID NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price DOUBLE PRECISION NOT NULL,
  is_included BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Bill Item Members (junction)
CREATE TABLE bill_item_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bill_item_id UUID NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Recurring Bills
CREATE TABLE recurring_bills (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  paid_by_member_id UUID NOT NULL REFERENCES members(id),
  category TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  title TEXT NOT NULL,
  frequency TEXT NOT NULL,
  next_due_date TIMESTAMPTZ NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Sync Log
CREATE TABLE sync_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id TEXT NOT NULL,
  household_id UUID REFERENCES households(id) ON DELETE CASCADE,
  last_synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER households_updated_at BEFORE UPDATE ON households FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER members_updated_at BEFORE UPDATE ON members FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER bills_updated_at BEFORE UPDATE ON bills FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER bill_items_updated_at BEFORE UPDATE ON bill_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER recurring_bills_updated_at BEFORE UPDATE ON recurring_bills FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email, NEW.phone, 'User'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

**Step 2: Commit**

```bash
git add supabase/migrations/001_initial_schema.sql
git commit -m "feat: Supabase schema — tables, triggers, auto-profile creation"
```

---

## Task 3: Supabase RLS Policies

**Files:**
- Create: `supabase/migrations/002_rls_policies.sql`

**Step 1: Create RLS policies**

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_item_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update their own profile
CREATE POLICY "Users can read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Helper: check if user is a member of household
CREATE OR REPLACE FUNCTION is_household_member(h_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM members
    WHERE household_id = h_id
      AND user_id = auth.uid()
      AND deleted_at IS NULL
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper: check if user is admin of household
CREATE OR REPLACE FUNCTION is_household_admin(h_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM members
    WHERE household_id = h_id
      AND user_id = auth.uid()
      AND is_admin = true
      AND deleted_at IS NULL
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Households: members can read, anyone authenticated can create
CREATE POLICY "Members can read household" ON households FOR SELECT USING (is_household_member(id));
CREATE POLICY "Authenticated users can create household" ON households FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Admins can update household" ON households FOR UPDATE USING (is_household_admin(id));

-- Members: household members can read, admins can insert/update/delete
CREATE POLICY "Members can read members" ON members FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Admins can insert members" ON members FOR INSERT WITH CHECK (is_household_admin(household_id) OR auth.uid() IS NOT NULL);
CREATE POLICY "Admins can update members" ON members FOR UPDATE USING (
  is_household_admin(household_id) OR user_id = auth.uid()
);

-- Bills: household members can read/insert, payer or admin can delete
CREATE POLICY "Members can read bills" ON bills FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Members can insert bills" ON bills FOR INSERT WITH CHECK (is_household_member(household_id));
CREATE POLICY "Members can update own or admin bills" ON bills FOR UPDATE USING (
  is_household_member(household_id)
);
CREATE POLICY "Payer or admin can delete bills" ON bills FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM members
    WHERE members.id = bills.paid_by_member_id
      AND members.user_id = auth.uid()
  )
  OR is_household_admin(household_id)
);

-- Bill Items: follow bill access
CREATE POLICY "Members can read bill items" ON bill_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM bills WHERE bills.id = bill_items.bill_id AND is_household_member(bills.household_id))
);
CREATE POLICY "Members can insert bill items" ON bill_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM bills WHERE bills.id = bill_items.bill_id AND is_household_member(bills.household_id))
);
CREATE POLICY "Members can update bill items" ON bill_items FOR UPDATE USING (
  EXISTS (SELECT 1 FROM bills WHERE bills.id = bill_items.bill_id AND is_household_member(bills.household_id))
);

-- Bill Item Members: follow bill item access
CREATE POLICY "Members can read bill item members" ON bill_item_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM bill_items bi
    JOIN bills b ON b.id = bi.bill_id
    WHERE bi.id = bill_item_members.bill_item_id
      AND is_household_member(b.household_id)
  )
);
CREATE POLICY "Members can insert bill item members" ON bill_item_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM bill_items bi
    JOIN bills b ON b.id = bi.bill_id
    WHERE bi.id = bill_item_members.bill_item_id
      AND is_household_member(b.household_id)
  )
);

-- Recurring Bills: household members can CRUD
CREATE POLICY "Members can read recurring bills" ON recurring_bills FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Members can insert recurring bills" ON recurring_bills FOR INSERT WITH CHECK (is_household_member(household_id));
CREATE POLICY "Members can update recurring bills" ON recurring_bills FOR UPDATE USING (is_household_member(household_id));

-- Sync Log: user can manage own sync log
CREATE POLICY "Users can manage own sync log" ON sync_log FOR ALL USING (
  is_household_member(household_id)
);
```

**Step 2: Create storage bucket policy**

```sql
-- Storage: receipts bucket (create via dashboard, policies via SQL)
INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', false);

CREATE POLICY "Members can read receipts" ON storage.objects FOR SELECT USING (
  bucket_id = 'receipts' AND
  is_household_member((storage.foldername(name))[1]::UUID)
);

CREATE POLICY "Members can upload receipts" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'receipts' AND auth.uid() IS NOT NULL
);

CREATE POLICY "Members can delete own receipts" ON storage.objects FOR DELETE USING (
  bucket_id = 'receipts' AND auth.uid() IS NOT NULL
);
```

**Step 3: Commit**

```bash
git add supabase/migrations/002_rls_policies.sql
git commit -m "feat: RLS policies for all tables and storage bucket"
```

---

## Task 4: Local DB Migration v10 — Add remote_id and sync columns

**Files:**
- Modify: `lib/database/database_helper.dart`

**Step 1: Bump DB version to 10 and add migration**

Change version from `9` to `10` (line 26).

Add to `_onUpgrade`:

```dart
if (oldVersion < 10) {
  // Add remote_id (UUID) to all synced tables
  await db.execute("ALTER TABLE households ADD COLUMN remote_id TEXT");
  await db.execute("ALTER TABLE members ADD COLUMN remote_id TEXT");
  await db.execute("ALTER TABLE bills ADD COLUMN remote_id TEXT");
  await db.execute("ALTER TABLE bills ADD COLUMN photo_url TEXT");
  await db.execute("ALTER TABLE bill_items ADD COLUMN remote_id TEXT");
  await db.execute("ALTER TABLE bill_item_members ADD COLUMN remote_id TEXT");
  await db.execute("ALTER TABLE recurring_bills ADD COLUMN remote_id TEXT");
  await db.execute("ALTER TABLE bills ADD COLUMN deleted_by_member_id INTEGER");

  // Add updated_at to all synced tables for conflict resolution
  await db.execute("ALTER TABLE households ADD COLUMN updated_at TEXT");
  await db.execute("ALTER TABLE members ADD COLUMN updated_at TEXT");
  await db.execute("ALTER TABLE bills ADD COLUMN updated_at TEXT");
  await db.execute("ALTER TABLE bill_items ADD COLUMN updated_at TEXT");
  await db.execute("ALTER TABLE recurring_bills ADD COLUMN updated_at TEXT");

  // Sync queue table
  await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      row_id INTEGER NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
}
```

Also add `remote_id`, `updated_at`, `photo_url`, `deleted_by_member_id` to the `_onCreate` table definitions so fresh installs get them.

**Step 2: Update model toMap/fromMap methods**

Add `remote_id` and `updated_at` to `Household`, `Member`, `Bill`, `BillItem`, `RecurringBill` models. Add `photoUrl` and `deletedByMemberId` to `Bill`.

**Step 3: Commit**

```bash
git add lib/database/database_helper.dart lib/models/
git commit -m "feat: DB migration v10 — add remote_id, updated_at, sync_queue table"
```

---

## Task 5: Data Repository Interface

**Files:**
- Create: `lib/database/data_repository.dart`

**Step 1: Create abstract interface**

Extract the public API of `DatabaseHelper` into an abstract class:

```dart
import '../models/household.dart';
import '../models/member.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/recurring_bill.dart';

abstract class DataRepository {
  // Households
  Future<int> insertHousehold(Household household);
  Future<List<Household>> getHouseholds();
  Future<void> deleteHousehold(int id);
  Future<void> updateHouseholdCurrency(int id, String currency);

  // Members
  Future<int> insertMember(Member member);
  Future<List<Member>> getMembersByHousehold(int householdId);
  Future<List<Member>> getAllMembersByHousehold(int householdId);
  Future<void> updateMemberName(int memberId, String name);
  Future<void> updateMemberPin(int memberId, String? pin);
  Future<void> setMemberActive(int memberId, bool active);

  // Bills
  Future<int> insertBill(Bill bill);
  Future<List<Bill>> getBillsByHousehold(int householdId);
  Future<Bill?> getBill(int id);
  Future<void> deleteBill(int id);

  // Bill Items
  Future<void> insertBillItems(List<BillItem> items);
  Future<List<BillItem>> getBillItems(int billId);
  Future<void> insertBillItemMembers(int billItemId, List<int> memberIds);
  Future<List<int>> getBillItemMemberIds(int billItemId);
  Future<void> deleteBillItemMembers(int billItemId);

  // Recurring Bills
  Future<int> insertRecurringBill(RecurringBill recurringBill);
  Future<List<RecurringBill>> getRecurringBillsByHousehold(int householdId);
  Future<List<RecurringBill>> getDueRecurringBills(int householdId);
  Future<void> updateRecurringBillNextDate(int id, DateTime nextDate);
  Future<void> deactivateRecurringBill(int id);
  Future<void> reactivateRecurringBill(int id);
  Future<void> updateRecurringBill(RecurringBill bill);
  Future<void> deleteRecurringBillPermanently(int id);

  // Utility
  Future<void> fixNewMemberDates(int householdId);
  Future<int> createHouseholdWithMembers(String name, List<String> memberNames);
}
```

**Step 2: Make DatabaseHelper implement DataRepository**

Change class declaration to: `class DatabaseHelper implements DataRepository`

**Step 3: Commit**

```bash
git add lib/database/data_repository.dart lib/database/database_helper.dart
git commit -m "feat: extract DataRepository interface from DatabaseHelper"
```

---

## Task 6: Auth Service

**Files:**
- Create: `lib/services/auth_service.dart`

**Step 1: Create AuthService with Supabase auth methods**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Email/password sign up
  Future<AuthResponse> signUpWithEmail(String email, String password, String displayName) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  // Email/password sign in
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  // Phone/OTP sign up
  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  // Verify OTP
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    return await _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  // Google sign in
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(serverClientId: 'YOUR_GOOGLE_CLIENT_ID');
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );
  }

  // Apple sign in
  Future<AuthResponse> signInWithApple() async {
    return await _client.auth.signInWithApple();
  }

  // Link social provider to existing account
  Future<void> linkGoogle() async {
    // User must be already signed in
    await signInWithGoogle();
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Update display name
  Future<void> updateDisplayName(String name) async {
    await _client.from('profiles').update({'display_name': name}).eq('id', currentUser!.id);
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: AuthService with email, phone, Google, Apple sign-in"
```

---

## Task 7: Auth Provider

**Files:**
- Create: `lib/providers/auth_provider.dart`

**Step 1: Create AuthProvider wrapping AuthService**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  bool _loading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSub;

  AuthProvider(this._authService) {
    _user = _authService.currentUser;
    _authSub = _authService.authStateChanges.listen((state) {
      _user = state.session?.user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> signUpWithEmail(String email, String password, String displayName) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signUpWithEmail(email, password, displayName);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithEmail(email, password);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPhoneOtp(String phone) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithPhone(phone);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String phone, String code) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.verifyOtp(phone, code);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithGoogle();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithApple();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
```

**Step 2: Commit**

```bash
git add lib/providers/auth_provider.dart
git commit -m "feat: AuthProvider with loading/error state management"
```

---

## Task 8: Auth Screens — Onboarding, Sign Up, Sign In

**Files:**
- Create: `lib/screens/onboarding_screen.dart`
- Create: `lib/screens/auth_screen.dart`

**Step 1: Create OnboardingScreen**

First launch screen with two options:
- "Sign Up" / "Sign In" → navigates to AuthScreen
- "Continue without account" → navigates to existing HouseholdScreen (local mode)

Styled with app theme, centered logo/title, two buttons.

**Step 2: Create AuthScreen**

Tabbed screen with Sign Up and Sign In tabs:

**Sign Up tab:**
- Toggle: Email / Phone
- Email mode: email field, password field, display name field, "Sign Up" button
- Phone mode: phone field, "Send Code" button → OTP field, "Verify" button
- Divider with "or"
- Google sign-in button, Apple sign-in button
- Error display from `AuthProvider.error`
- Loading indicator from `AuthProvider.loading`

**Sign In tab:**
- Same layout as Sign Up but for existing accounts
- Email mode: email + password fields
- Phone mode: phone + OTP flow

**Step 3: Update main.dart**

- Initialize Supabase in `main()` before `runApp`:
```dart
await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
```
- Add `AuthProvider` to MultiProvider
- Add routes: `/onboarding`, `/auth`
- Change initial route logic: if user is authenticated → `/households`, else → `/onboarding`

**Step 4: Commit**

```bash
git add lib/screens/onboarding_screen.dart lib/screens/auth_screen.dart lib/main.dart
git commit -m "feat: onboarding and auth screens with email, phone, social sign-in"
```

---

## Task 9: Connectivity Service

**Files:**
- Create: `lib/services/connectivity_service.dart`

**Step 1: Create ConnectivityService**

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription? _sub;
  final _controller = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    _sub = _connectivity.onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);
      _controller.add(_isOnline);
      if (wasOffline && _isOnline) {
        // Trigger sync when coming back online — handled by SyncService listener
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/connectivity_service.dart
git commit -m "feat: ConnectivityService with online/offline state tracking"
```

---

## Task 10: Sync Queue — Local Operations Queue

**Files:**
- Create: `lib/database/sync_queue_helper.dart`

**Step 1: Create SyncQueueHelper for managing queued operations**

```dart
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class SyncQueueEntry {
  final int? id;
  final String tableName;
  final int rowId;
  final String operation; // 'insert', 'update', 'delete'
  final String payload; // JSON
  final String createdAt;

  SyncQueueEntry({
    this.id,
    required this.tableName,
    required this.rowId,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'table_name': tableName,
    'row_id': rowId,
    'operation': operation,
    'payload': payload,
    'created_at': createdAt,
  };

  factory SyncQueueEntry.fromMap(Map<String, dynamic> map) => SyncQueueEntry(
    id: map['id'] as int?,
    tableName: map['table_name'] as String,
    rowId: map['row_id'] as int,
    operation: map['operation'] as String,
    payload: map['payload'] as String,
    createdAt: map['created_at'] as String,
  );
}

class SyncQueueHelper {
  final DatabaseHelper _db;

  SyncQueueHelper(this._db);

  Future<void> enqueue(SyncQueueEntry entry) async {
    final db = await _db.database;
    await db.insert('sync_queue', entry.toMap());
  }

  Future<List<SyncQueueEntry>> getPending() async {
    final db = await _db.database;
    final maps = await db.query('sync_queue', orderBy: 'created_at ASC');
    return maps.map(SyncQueueEntry.fromMap).toList();
  }

  Future<void> remove(int id) async {
    final db = await _db.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('sync_queue');
  }

  Future<int> pendingCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
```

**Step 2: Commit**

```bash
git add lib/database/sync_queue_helper.dart
git commit -m "feat: SyncQueueHelper for local operation queuing"
```

---

## Task 11: Supabase Repository

**Files:**
- Create: `lib/database/supabase_repository.dart`

**Step 1: Create SupabaseRepository implementing the cloud CRUD operations**

This class talks directly to Supabase. It does NOT implement `DataRepository` — it uses UUIDs and cloud-specific logic. The `SyncService` bridges between local `DatabaseHelper` and this class.

Key methods:
- `upsertHousehold(Map<String, dynamic> data)` → inserts or updates by UUID
- `getHouseholdsSince(DateTime since)` → fetches rows updated after timestamp
- `upsertMember(...)`, `getMembersSince(...)`
- `upsertBill(...)`, `getBillsSince(...)`
- `upsertBillItem(...)`, `getBillItemsSince(...)`
- `upsertBillItemMember(...)`, `getBillItemMembersSince(...)`
- `upsertRecurringBill(...)`, `getRecurringBillsSince(...)`
- `uploadReceipt(String householdId, String billId, List<int> bytes)` → returns URL
- `deleteReceipt(String householdId, String billId)`
- `getSyncTimestamp(String deviceId, String householdId)` → last sync time
- `updateSyncTimestamp(String deviceId, String householdId)`

Each "get since" method filters by `updated_at > timestamp` and `deleted_at IS NULL` (or includes deleted rows for sync to process deletions).

**Step 2: Commit**

```bash
git add lib/database/supabase_repository.dart
git commit -m "feat: SupabaseRepository with cloud CRUD and receipt upload"
```

---

## Task 12: Sync Service

**Files:**
- Create: `lib/services/sync_service.dart`

**Step 1: Create SyncService**

The core sync engine. Orchestrates push (local → cloud) and pull (cloud → local).

```dart
class SyncService {
  final DatabaseHelper _local;
  final SupabaseRepository _remote;
  final SyncQueueHelper _queue;
  final ConnectivityService _connectivity;
  final String _deviceId; // generated once, stored in SharedPreferences
  bool _syncing = false;

  // Called on app open and when connectivity restores
  Future<void> sync(int householdId) async {
    if (_syncing || !_connectivity.isOnline) return;
    _syncing = true;
    try {
      await _pushPendingChanges(householdId);
      await _pullRemoteChanges(householdId);
    } finally {
      _syncing = false;
    }
  }

  // Push: process sync queue FIFO
  Future<void> _pushPendingChanges(int householdId) async {
    final pending = await _queue.getPending();
    for (final entry in pending) {
      try {
        // Read local row, get remote_id, upsert to Supabase
        // If insert and no remote_id, create UUID, upsert, save remote_id locally
        // If update, upsert by remote_id
        // If delete, set deleted_at on remote by remote_id
        await _processPush(entry);
        await _queue.remove(entry.id!);
      } catch (e) {
        // Leave in queue for retry
        break; // Stop processing on first failure
      }
    }
  }

  // Pull: fetch remote changes since last sync
  Future<void> _pullRemoteChanges(int householdId) async {
    final remoteId = /* get household remote_id */ '';
    final lastSync = await _remote.getSyncTimestamp(_deviceId, remoteId);

    // Pull each table in dependency order:
    // households → members → recurring_bills → bills → bill_items → bill_item_members
    // For each remote row:
    //   - Find local row by remote_id
    //   - If not found: insert locally with remote_id
    //   - If found: compare updated_at — if remote is newer, update local
    //   - If remote deleted_at is set: delete locally

    await _remote.updateSyncTimestamp(_deviceId, remoteId);
  }
}
```

Full implementation handles ID mapping (local int ↔ remote UUID), photo sync, and conflict resolution.

**Step 2: Commit**

```bash
git add lib/services/sync_service.dart
git commit -m "feat: SyncService with push/pull reconciliation and conflict resolution"
```

---

## Task 13: Wire Sync Into Providers

**Files:**
- Modify: `lib/providers/bill_provider.dart`
- Modify: `lib/providers/household_provider.dart`
- Modify: `lib/providers/recurring_bill_provider.dart`

**Step 1: Add sync queue writes to DatabaseHelper mutations**

Every mutating method in `DatabaseHelper` (insert, update, delete) should also enqueue a sync entry if the user is authenticated. Add a helper:

```dart
Future<void> _enqueueSync(String table, int rowId, String operation, Map<String, dynamic> payload) async {
  if (!_authService.isAuthenticated) return;
  await _syncQueue.enqueue(SyncQueueEntry(
    tableName: table,
    rowId: rowId,
    operation: operation,
    payload: jsonEncode(payload),
    createdAt: DateTime.now().toIso8601String(),
  ));
}
```

Call after each insert/update/delete in DatabaseHelper.

**Step 2: Trigger sync after provider operations**

In each provider's load/save methods, trigger `SyncService.sync()` when online:

```dart
await billProvider.loadBills(householdId);
if (authProvider.isAuthenticated) {
  syncService.sync(householdId); // fire and forget
}
```

**Step 3: Commit**

```bash
git add lib/providers/ lib/database/database_helper.dart
git commit -m "feat: wire sync queue into all mutating DB operations"
```

---

## Task 14: Bill Deletion Permissions

**Files:**
- Modify: `lib/screens/bill_detail_screen.dart`
- Modify: `lib/screens/home_screen.dart`

**Step 1: Add permission check to BillDetailScreen**

In the delete button/menu area, wrap with permission check:

```dart
final canDelete = bill.paidByMemberId == currentMember.id || currentMember.isAdmin;
```

Only show the delete option if `canDelete` is true.

**Step 2: Add permission check to HomeScreen swipe-to-delete**

In the `Dismissible` widget for bill list items, add the same check. If `canDelete` is false, don't wrap in `Dismissible` or set `confirmDismiss` to return false.

**Step 3: Track who deleted (for admin notifications in 5b)**

When admin deletes another member's bill, set `deletedByMemberId` on the bill before deleting:

```dart
if (currentMember.isAdmin && bill.paidByMemberId != currentMember.id) {
  // Store who deleted for notification purposes
  await db.update('bills', {'deleted_by_member_id': currentMember.id},
      where: 'id = ?', whereArgs: [bill.id]);
}
```

**Step 4: Commit**

```bash
git add lib/screens/bill_detail_screen.dart lib/screens/home_screen.dart
git commit -m "feat: bill deletion permissions — payer or admin only"
```

---

## Task 15: Receipt Photo Compression and Upload

**Files:**
- Modify: `lib/providers/bill_provider.dart`
- Create: `lib/services/image_compress_service.dart`

**Step 1: Create ImageCompressService**

```dart
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressService {
  /// Compress image to max 1200px wide, 70% JPEG quality
  static Future<File> compress(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 1200,
      minHeight: 1200,
      quality: 70,
    );
    return File(result!.path);
  }
}
```

**Step 2: Update BillProvider.saveBill to compress before saving**

Before copying the photo to app docs directory, compress it:

```dart
if (tempPhotoPath != null) {
  final compressed = await ImageCompressService.compress(File(tempPhotoPath));
  // Copy compressed file to docs dir
  // ...existing copy logic using compressed.path...
}
```

**Step 3: Photo upload handled by SyncService**

When `SyncService` pushes a bill with a `photo_path` and no `photo_url`, it:
1. Reads the local file
2. Calls `SupabaseRepository.uploadReceipt()`
3. Updates `photo_url` on both local and remote bill

**Step 4: Commit**

```bash
git add lib/services/image_compress_service.dart lib/providers/bill_provider.dart
git commit -m "feat: receipt photo compression and cloud upload via sync"
```

---

## Task 16: Local Data Migration Prompt

**Files:**
- Create: `lib/widgets/data_migration_sheet.dart`
- Modify: `lib/screens/auth_screen.dart`

**Step 1: Create DataMigrationSheet**

A bottom sheet shown after first sign-up if local data exists:

```dart
class DataMigrationSheet extends StatefulWidget {
  final int billCount;
  final int householdCount;
  final VoidCallback onUpload;
  final VoidCallback onSkip;
  // ...
}
```

Shows: "You have X bills across Y households. Upload to your new account?"
Two buttons: "Upload" (with progress indicator) and "Start Fresh"

**Step 2: Create migration logic**

Create `lib/services/data_migration_service.dart`:

```dart
class DataMigrationService {
  /// Migrate all local data to Supabase
  /// Returns progress stream (0.0 to 1.0)
  Stream<double> migrateLocalData(DatabaseHelper local, SupabaseRepository remote) async* {
    // 1. Get all local households
    // 2. For each household: insert to Supabase, get UUID, save remote_id locally
    // 3. For each member: insert, map IDs
    // 4. For each recurring bill: insert, map IDs
    // 5. For each bill: insert, map IDs (skip rows with remote_id already set)
    // 6. For each bill_item: insert, map IDs
    // 7. For each bill_item_member: insert, map IDs
    // 8. For each bill with photo_path: upload photo
    // Yield progress after each batch
  }
}
```

**Step 3: Trigger after successful auth**

In `AuthScreen`, after successful sign-up, check local data count. If > 0, show `DataMigrationSheet`.

**Step 4: Commit**

```bash
git add lib/widgets/data_migration_sheet.dart lib/services/data_migration_service.dart lib/screens/auth_screen.dart
git commit -m "feat: local data migration prompt with upload progress"
```

---

## Task 17: Initialize Supabase and Wire Everything in main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Initialize Supabase**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... existing AppScale init ...

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final connectivityService = ConnectivityService();
  await connectivityService.init();

  final authService = AuthService(Supabase.instance.client);
  final syncQueueHelper = SyncQueueHelper(DatabaseHelper.instance);
  final supabaseRepo = SupabaseRepository(Supabase.instance.client);
  final syncService = SyncService(
    DatabaseHelper.instance,
    supabaseRepo,
    syncQueueHelper,
    connectivityService,
  );

  // ... existing settings load ...

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => HouseholdProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => RecurringBillProvider()),
        Provider.value(value: connectivityService),
        Provider.value(value: syncService),
      ],
      child: const BillSplitApp(),
    ),
  );
}
```

**Step 2: Update route logic**

```dart
initialRoute: authProvider.isAuthenticated ? '/households' : '/onboarding',
```

Add new routes:
```dart
'/onboarding': (context) => const OnboardingScreen(),
'/auth': (context) => const AuthScreen(),
```

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize Supabase, wire auth/sync/connectivity into app"
```

---

## Task 18: Final Integration and Polish

**Files:**
- Various

**Step 1: Add sign-out option to SettingsScreen**

Add a "Sign Out" button at the bottom of SettingsScreen (only visible when authenticated). On sign out, navigate to onboarding.

**Step 2: Show sync status indicator**

Add a small sync icon to the home screen app bar that shows:
- Cloud icon when synced
- Spinning icon when syncing
- Offline icon with pending count when offline

**Step 3: Add "Account" section to SettingsScreen**

Show user email/phone, linked social providers, option to link Google/Apple if not already linked.

**Step 4: Run flutter analyze**

```bash
flutter analyze
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: Phase 5a complete — sign out, sync indicator, account settings"
```
