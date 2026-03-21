import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';

class MonthlySummary {
  final int billCount;
  final Map<int, double> memberSpend; // memberId -> total spent
  final String monthLabel;

  MonthlySummary({
    required this.billCount,
    required this.memberSpend,
    required this.monthLabel,
  });
}

class MonthlyInsights {
  final String monthLabel;
  final int year;
  final int month;
  final int billCount;
  final double totalSpent;
  final Map<String, double> categorySpend;
  final Map<int, double> memberSpend;

  MonthlyInsights({
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.billCount,
    required this.totalSpent,
    required this.categorySpend,
    required this.memberSpend,
  });
}

class BillProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Bill> _bills = [];
  Map<int, double> _memberBalances = {};
  MonthlySummary? _monthlySummary;

  // Cache key: bill count + sum of IDs to detect changes cheaply
  int _balanceCacheKey = -1;

  List<Bill> get bills => _bills;
  Map<int, double> get memberBalances => _memberBalances;
  MonthlySummary? get monthlySummary => _monthlySummary;

  int _computeCacheKey() {
    if (_bills.isEmpty) return 0;
    return Object.hash(
      _bills.length,
      _bills.fold<int>(0, (sum, b) => sum + (b.id ?? 0)),
    );
  }

  Future<void> loadBills(int householdId) async {
    _bills = await _db.getBillsByHousehold(householdId);
    final newKey = _computeCacheKey();
    if (newKey != _balanceCacheKey) {
      await _calculateBalances(householdId);
      _balanceCacheKey = newKey;
    }
    _calculateMonthlySummary();
    notifyListeners();
  }

  Future<void> _calculateBalances(int householdId) async {
    final members = await _db.getMembersByHousehold(householdId);
    _memberBalances = {for (final m in members) m.id!: 0.0};

    for (final bill in _bills) {
      final payerId = bill.paidByMemberId;

      if (bill.billType == 'settlement') {
        // Settlement: payer transfers money to a specific receiver.
        // Only the payer-receiver pair is affected.
        final receiverId = bill.receiverMemberId;
        if (receiverId != null) {
          _memberBalances[payerId] =
              (_memberBalances[payerId] ?? 0) + bill.totalAmount;
          _memberBalances[receiverId] =
              (_memberBalances[receiverId] ?? 0) - bill.totalAmount;
        } else {
          // Legacy settlements (before v5) without receiverMemberId:
          // fall back to splitting across all other members.
          final otherMembers = members.where((m) => m.id != payerId).toList();
          if (otherMembers.isNotEmpty) {
            final perPerson = bill.totalAmount / otherMembers.length;
            _memberBalances[payerId] =
                (_memberBalances[payerId] ?? 0) + bill.totalAmount;
            for (final other in otherMembers) {
              _memberBalances[other.id!] =
                  (_memberBalances[other.id!] ?? 0) - perPerson;
            }
          }
        }
      } else if (bill.billType == 'quick') {
        // Quick bill: split equally among ALL members.
        // Payer gets credit for what others owe; each other member is debited their share.
        final totalMembers = members.length;
        if (totalMembers > 1) {
          final perPersonShare = bill.totalAmount / totalMembers;
          final otherMembers = members.where((m) => m.id != payerId).toList();
          for (final other in otherMembers) {
            _memberBalances[payerId] =
                (_memberBalances[payerId] ?? 0) + perPersonShare;
            _memberBalances[other.id!] =
                (_memberBalances[other.id!] ?? 0) - perPersonShare;
          }
        }
      } else {
        // Full bill: iterate items, use sharedByMemberIds for per-item splitting.
        final items = await _db.getBillItems(bill.id!);

        for (final item in items) {
          if (item.isIncluded && item.sharedByMemberIds.isNotEmpty) {
            final perMemberShare = item.price / item.sharedByMemberIds.length;
            for (final memberId in item.sharedByMemberIds) {
              if (memberId != payerId) {
                _memberBalances[payerId] =
                    (_memberBalances[payerId] ?? 0) + perMemberShare;
                _memberBalances[memberId] =
                    (_memberBalances[memberId] ?? 0) - perMemberShare;
              }
            }
          }
        }
      }
    }
  }

  void _calculateMonthlySummary() {
    final now = DateTime.now();
    final thisMonthBills = _bills.where((b) =>
        b.billDate.year == now.year &&
        b.billDate.month == now.month &&
        b.billType != 'settlement').toList();

    final memberSpend = <int, double>{};
    for (final bill in thisMonthBills) {
      memberSpend[bill.paidByMemberId] =
          (memberSpend[bill.paidByMemberId] ?? 0) + bill.totalAmount;
    }

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    _monthlySummary = MonthlySummary(
      billCount: thisMonthBills.length,
      memberSpend: memberSpend,
      monthLabel: '${months[now.month - 1]} ${now.year}',
    );
  }

  Future<void> saveBill({
    required Bill bill,
    required List<BillItem> items,
    String? tempPhotoPath,
  }) async {
    String? permanentPhotoPath;
    if (tempPhotoPath != null) {
      permanentPhotoPath = await _savePhoto(tempPhotoPath);
    }

    final billToSave = Bill(
      householdId: bill.householdId,
      enteredByMemberId: bill.enteredByMemberId,
      paidByMemberId: bill.paidByMemberId,
      billType: bill.billType,
      totalAmount: bill.totalAmount,
      photoPath: permanentPhotoPath,
      billDate: bill.billDate,
      category: bill.category,
      recurringBillId: bill.recurringBillId,
    );

    final billId = await _db.insertBill(billToSave);

    if (items.isNotEmpty) {
      final itemsWithBillId = items
          .map((item) => BillItem(
                billId: billId,
                name: item.name,
                price: item.price,
                isIncluded: item.isIncluded,
                sharedByMemberIds: item.sharedByMemberIds,
              ))
          .toList();
      await _db.insertBillItems(itemsWithBillId);
    }

    await loadBills(bill.householdId);
  }

  Future<void> settleUp({
    required int householdId,
    required int payerMemberId,
    required int receiverMemberId,
    required double amount,
  }) async {
    final bill = Bill(
      householdId: householdId,
      enteredByMemberId: payerMemberId,
      paidByMemberId: payerMemberId,
      billType: 'settlement',
      totalAmount: amount,
      billDate: DateTime.now(),
      category: 'other',
      receiverMemberId: receiverMemberId,
    );
    await _db.insertBill(bill);
    await loadBills(householdId);
  }

  Future<String> _savePhoto(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'receipt_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final fileName =
        'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile =
        await File(tempPath).copy(p.join(photosDir.path, fileName));
    return savedFile.path;
  }

  Future<Bill?> getBill(int billId) async {
    return await _db.getBill(billId);
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    return await _db.getBillItems(billId);
  }

  Future<void> deleteBill(int billId, int householdId) async {
    final bill = await _db.getBill(billId);
    if (bill?.photoPath != null) {
      final file = File(bill!.photoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.deleteBill(billId);
    await loadBills(householdId);
  }

  /// Re-insert a bill for undo support
  Future<void> reinsertBill(Bill bill, List<BillItem> items) async {
    final billId = await _db.insertBill(bill);
    if (items.isNotEmpty) {
      final itemsWithBillId = items
          .map((item) => BillItem(
                billId: billId,
                name: item.name,
                price: item.price,
                isIncluded: item.isIncluded,
                sharedByMemberIds: item.sharedByMemberIds,
              ))
          .toList();
      await _db.insertBillItems(itemsWithBillId);
    }
    await loadBills(bill.householdId);
  }

  MonthlyInsights getInsightsForMonth(int year, int month) {
    final monthBills = _bills.where((b) =>
        b.billDate.year == year &&
        b.billDate.month == month &&
        b.billType != 'settlement').toList();

    final categorySpend = <String, double>{};
    final memberSpend = <int, double>{};
    double totalSpent = 0;

    for (final bill in monthBills) {
      totalSpent += bill.totalAmount;
      categorySpend[bill.category] =
          (categorySpend[bill.category] ?? 0) + bill.totalAmount;
      memberSpend[bill.paidByMemberId] =
          (memberSpend[bill.paidByMemberId] ?? 0) + bill.totalAmount;
    }

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return MonthlyInsights(
      monthLabel: '${months[month - 1]} $year',
      year: year,
      month: month,
      billCount: monthBills.length,
      totalSpent: totalSpent,
      categorySpend: categorySpend,
      memberSpend: memberSpend,
    );
  }

  /// Returns the date of the oldest bill, or null if no bills exist.
  DateTime? get oldestBillDate {
    if (_bills.isEmpty) return null;
    return _bills
        .map((b) => b.billDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }
}
