import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/recurring_bill.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';

class RecurringBillProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<RecurringBill> _dueBills = [];
  List<RecurringBill> get dueBills => _dueBills;

  Future<void> loadDueBills(int householdId) async {
    _dueBills = await _db.getDueRecurringBills(householdId);
    notifyListeners();
  }

  Future<void> confirmBill(RecurringBill recurring, BillProvider billProvider,
      int householdId, int enteredByMemberId) async {
    // Create the actual bill
    final bill = Bill(
      householdId: householdId,
      enteredByMemberId: enteredByMemberId,
      paidByMemberId: recurring.paidByMemberId,
      billType: 'quick',
      totalAmount: recurring.amount,
      billDate: DateTime.now(),
      category: recurring.category,
      recurringBillId: recurring.id,
    );
    await billProvider.saveBill(bill: bill, items: []);

    // Advance the due date
    final nextDate = recurring.getNextDueDate();
    await _db.updateRecurringBillNextDate(recurring.id!, nextDate);
    await loadDueBills(householdId);
  }

  Future<void> dismissBill(RecurringBill recurring, int householdId) async {
    // Skip this occurrence — advance to next due date
    final nextDate = recurring.getNextDueDate();
    await _db.updateRecurringBillNextDate(recurring.id!, nextDate);
    await loadDueBills(householdId);
  }

  Future<void> createRecurring({
    required int householdId,
    required int paidByMemberId,
    required String category,
    required double amount,
    required String title,
    required String frequency,
  }) async {
    // Calculate first due date based on frequency
    final now = DateTime.now();
    DateTime nextDue;
    switch (frequency) {
      case 'weekly':
        nextDue = now.add(const Duration(days: 7));
      case 'yearly':
        final maxDay = DateTime(now.year + 2, now.month, 0).day;
        final clampedDay = now.day > maxDay ? maxDay : now.day;
        nextDue = DateTime(now.year + 1, now.month, clampedDay);
      default: // monthly
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        final maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
        final clampedDay = now.day > maxDay ? maxDay : now.day;
        nextDue = DateTime(nextYear, nextMonth, clampedDay);
    }

    await _db.insertRecurringBill(RecurringBill(
      householdId: householdId,
      paidByMemberId: paidByMemberId,
      category: category,
      amount: amount,
      title: title,
      frequency: frequency,
      nextDueDate: nextDue,
    ));
    await loadDueBills(householdId);
  }

  Future<void> deleteRecurring(int id, int householdId) async {
    await _db.deactivateRecurringBill(id);
    await loadDueBills(householdId);
  }
}
