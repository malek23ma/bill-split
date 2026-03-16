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

class BillProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Bill> _bills = [];
  Map<int, double> _memberBalances = {};
  MonthlySummary? _monthlySummary;

  List<Bill> get bills => _bills;
  Map<int, double> get memberBalances => _memberBalances;
  MonthlySummary? get monthlySummary => _monthlySummary;

  Future<void> loadBills(int householdId) async {
    _bills = await _db.getBillsByHousehold(householdId);
    await _calculateBalances(householdId);
    _calculateMonthlySummary();
    notifyListeners();
  }

  Future<void> _calculateBalances(int householdId) async {
    final members = await _db.getMembersByHousehold(householdId);
    _memberBalances = {for (final m in members) m.id!: 0.0};

    for (final bill in _bills) {
      final payerId = bill.paidByMemberId;

      if (bill.billType == 'settlement') {
        // Settlement: payer paid their debt, so they get credit
        for (final member in members) {
          if (member.id != payerId) {
            _memberBalances[payerId] =
                (_memberBalances[payerId] ?? 0) + bill.totalAmount;
            _memberBalances[member.id!] =
                (_memberBalances[member.id!] ?? 0) - bill.totalAmount;
          }
        }
      } else if (bill.billType == 'quick') {
        final otherShare = bill.totalAmount / 2;
        for (final member in members) {
          if (member.id != payerId) {
            _memberBalances[payerId] =
                (_memberBalances[payerId] ?? 0) + otherShare;
            _memberBalances[member.id!] =
                (_memberBalances[member.id!] ?? 0) - otherShare;
          }
        }
      } else {
        final items = await _db.getBillItems(bill.id!);
        double totalOwedToPayerByOthers = 0;

        for (final item in items) {
          if (item.isIncluded) {
            final othersShare = item.price * (100 - item.splitPercent) / 100;
            totalOwedToPayerByOthers += othersShare;
          }
        }

        final otherMembers = members.where((m) => m.id != payerId).toList();
        if (otherMembers.isNotEmpty) {
          final perPerson = totalOwedToPayerByOthers / otherMembers.length;
          for (final other in otherMembers) {
            _memberBalances[payerId] =
                (_memberBalances[payerId] ?? 0) + perPerson;
            _memberBalances[other.id!] =
                (_memberBalances[other.id!] ?? 0) - perPerson;
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
    );

    final billId = await _db.insertBill(billToSave);

    if (items.isNotEmpty) {
      final itemsWithBillId = items
          .map((item) => BillItem(
                billId: billId,
                name: item.name,
                price: item.price,
                isIncluded: item.isIncluded,
                splitPercent: item.splitPercent,
              ))
          .toList();
      await _db.insertBillItems(itemsWithBillId);
    }

    await loadBills(bill.householdId);
  }

  Future<void> settleUp({
    required int householdId,
    required int payerMemberId,
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
                splitPercent: item.splitPercent,
              ))
          .toList();
      await _db.insertBillItems(itemsWithBillId);
    }
    await loadBills(bill.householdId);
  }
}
