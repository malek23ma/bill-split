import 'package:flutter/material.dart';
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

  Future<void> deleteHousehold(int id) async {
    await _db.deleteHousehold(id);
    if (_currentHousehold?.id == id) {
      _currentHousehold = null;
      _currentMember = null;
      _members = [];
    }
    await loadHouseholds();
  }
}
