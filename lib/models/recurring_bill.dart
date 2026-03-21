class RecurringBill {
  final int? id;
  final int householdId;
  final int paidByMemberId;
  final String category;
  final double amount;
  final String title;
  final String frequency; // 'weekly', 'monthly', 'yearly'
  final DateTime nextDueDate;
  final bool active;

  RecurringBill({
    this.id,
    required this.householdId,
    required this.paidByMemberId,
    required this.category,
    required this.amount,
    required this.title,
    required this.frequency,
    required this.nextDueDate,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'paid_by_member_id': paidByMemberId,
      'category': category,
      'amount': amount,
      'title': title,
      'frequency': frequency,
      'next_due_date': nextDueDate.toIso8601String(),
      'active': active ? 1 : 0,
    };
  }

  factory RecurringBill.fromMap(Map<String, dynamic> map) {
    return RecurringBill(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      paidByMemberId: map['paid_by_member_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      frequency: map['frequency'] as String,
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      active: (map['active'] as int) == 1,
    );
  }

  /// Returns the next due date after the current nextDueDate based on frequency.
  DateTime getNextDueDate() {
    switch (frequency) {
      case 'weekly':
        return nextDueDate.add(const Duration(days: 7));
      case 'monthly':
        final nextYear = nextDueDate.year + (nextDueDate.month == 12 ? 1 : 0);
        final nextMonth = nextDueDate.month == 12 ? 1 : nextDueDate.month + 1;
        final maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
        final clampedDay = nextDueDate.day > maxDay ? maxDay : nextDueDate.day;
        return DateTime(nextYear, nextMonth, clampedDay);
      case 'yearly':
        final maxDay = DateTime(nextDueDate.year + 2, nextDueDate.month, 0).day;
        final clampedDay = nextDueDate.day > maxDay ? maxDay : nextDueDate.day;
        return DateTime(nextDueDate.year + 1, nextDueDate.month, clampedDay);
      default:
        return nextDueDate.add(const Duration(days: 30));
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringBill && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
