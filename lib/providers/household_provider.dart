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

  Future<Household> createHousehold(String name, List<String> memberNames) async {
    final id = await _db.createHouseholdWithMembers(name, memberNames);
    await loadHouseholds();
    return _households.firstWhere((h) => h.id == id);
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

  /// Auto-set currentMember by matching auth user_id to a member in the household.
  /// Tries cloud lookup first, then falls back to matching by display name.
  Future<Member?> resolveCurrentMember(String authUserId) async {
    if (_currentHousehold == null) return null;

    // Strategy 1: Cloud lookup by user_id
    try {
      final supabase = Supabase.instance.client;
      final remoteHouseholdId = _currentHousehold!.remoteId;
      if (remoteHouseholdId != null && remoteHouseholdId.length > 8) {
        final remoteMember = await supabase
            .from('members')
            .select('id')
            .eq('household_id', remoteHouseholdId)
            .eq('user_id', authUserId)
            .maybeSingle();
        if (remoteMember != null) {
          final remoteId = remoteMember['id'] as String;
          final match = _members.where((m) => m.remoteId == remoteId).firstOrNull;
          if (match != null) {
            _currentMember = match;
            notifyListeners();
            return match;
          }
        }
      }
    } catch (_) {}

    // Strategy 2: Match by display name from auth profile (cloud)
    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', authUserId)
          .maybeSingle();
      if (profile != null) {
        final displayName = profile['display_name'] as String?;
        if (displayName != null) {
          final match = _members.where(
            (m) => m.name.toLowerCase() == displayName.toLowerCase()
          ).firstOrNull;
          if (match != null) {
            _currentMember = match;
            notifyListeners();
            // Also link this member to the auth user in the cloud for future lookups
            if (match.remoteId != null && match.remoteId!.length > 8) {
              try {
                await supabase.from('members').update({'user_id': authUserId}).eq('id', match.remoteId!);
              } catch (_) {}
            }
            return match;
          }
        }
      }
    } catch (_) {}

    // Strategy 3: Match by display name from auth metadata (local, no network needed)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final metaName = user?.userMetadata?['display_name'] as String?;
      final email = user?.email;
      // Try metadata display_name first
      if (metaName != null) {
        final match = _members.where(
          (m) => m.name.toLowerCase() == metaName.toLowerCase()
        ).firstOrNull;
        if (match != null) {
          _currentMember = match;
          notifyListeners();
          return match;
        }
      }
      // Try email username as fallback (e.g., "malek23almously" from email)
      if (email != null) {
        final emailName = email.split('@').first.toLowerCase();
        final match = _members.where(
          (m) => m.name.toLowerCase().contains(emailName) || emailName.contains(m.name.toLowerCase())
        ).firstOrNull;
        if (match != null) {
          _currentMember = match;
          notifyListeners();
          return match;
        }
      }
    } catch (_) {}

    // Strategy 4: If there's only one member, assume it's the current user
    if (_members.length == 1) {
      _currentMember = _members.first;
      notifyListeners();
      return _members.first;
    }

    // Strategy 5: If there's an admin member, assume it's the current user
    final admin = _members.where((m) => m.isAdmin).firstOrNull;
    if (admin != null && _members.length <= 2) {
      _currentMember = admin;
      notifyListeners();
      return admin;
    }

    return null;
  }

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
      return _households
          .where((h) => h.remoteId != null && remoteHouseholdIds.contains(h.remoteId))
          .toList();
    } catch (_) {
      return _households;
    }
  }
}
