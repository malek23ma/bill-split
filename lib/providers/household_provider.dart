import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../constants.dart';
import '../models/household.dart';
import '../models/member.dart';

class HouseholdProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Household> _households = [];
  Household? _currentHousehold;
  Member? _currentMember;
  List<Member> _members = [];

  List<Household> get households => _households;
  Household? get currentHousehold => _currentHousehold;
  Member? get currentMember => _currentMember;
  List<Member> get members => _members;

  Future<void> loadHouseholds() async {
    _households = await _db.getHouseholds();
    notifyListeners();
  }

  /// Create a household with the current user as the sole admin member.
  Future<Household> createHouseholdForUser(String name, String userId, String displayName) async {
    final db = await _db.database;
    late int householdId;
    await db.transaction((txn) async {
      householdId = await txn.insert('households', Household(name: name).toMap());
      final member = Member(
        householdId: householdId,
        name: displayName,
        isAdmin: true,
        userId: userId,
      );
      await txn.insert('members', member.toMap());
    });
    await loadHouseholds();
    return _households.firstWhere((h) => h.id == householdId);
  }

  Future<void> setCurrentHousehold(Household household) async {
    _currentHousehold = household;
    _members = await _db.getMembersByHousehold(household.id!);
    _currentMember = null;
    notifyListeners();
  }

  void setCurrentMember(Member member) {
    _currentMember = member;
    notifyListeners();
  }

  String get currency => _currentHousehold?.currency ?? 'TRY';

  String formatAmount(double amount) {
    if (_currentHousehold == null) return amount.toStringAsFixed(2);
    final curr = AppCurrency.getByCode(currency);
    return '${amount.toStringAsFixed(2)} ${curr.symbol}';
  }

  Future<void> addMember(String name) async {
    if (_currentHousehold == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) return;
    if (_members.any((m) => m.name.toLowerCase() == trimmed.toLowerCase())) return;
    await _db.insertMember(
      Member(householdId: _currentHousehold!.id!, name: trimmed),
    );
    _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
    notifyListeners();
  }

  Future<void> updateCurrency(String currency) async {
    if (_currentHousehold == null) return;
    await _db.updateHouseholdCurrency(_currentHousehold!.id!, currency);
    _currentHousehold = Household(
      id: _currentHousehold!.id,
      name: _currentHousehold!.name,
      currency: currency,
      createdAt: _currentHousehold!.createdAt,
    );
    notifyListeners();
  }

  Future<void> renameMember(int memberId, String newName) async {
    if (_currentHousehold == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.length > 50) return;
    if (_members.any((m) => m.id != memberId && m.name.toLowerCase() == trimmed.toLowerCase())) return;
    await _db.updateMemberName(memberId, trimmed);
    _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
    notifyListeners();
  }

  Future<bool> softDeleteMember(int memberId) async {
    if (_currentHousehold == null) return false;
    final activeCount = _members.where((m) => m.isActive).length;
    if (activeCount <= 1) return false;
    await _db.setMemberActive(memberId, false);
    if (_currentMember?.id == memberId) {
      _currentMember = null;
    }
    _members = await _db.getMembersByHousehold(_currentHousehold!.id!);
    notifyListeners();
    return true;
  }

  Future<void> deleteHousehold(int id) async {
    await _db.deleteHousehold(id);
    if (_currentHousehold?.id == id) {
      _currentHousehold = null;
      _currentMember = null;
      _members = [];
    }
    await loadHouseholds();
  }

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
}
