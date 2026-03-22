class Bill {
  final int? id;
  final int householdId;
  final int enteredByMemberId;
  final int paidByMemberId;
  final String billType; // 'full', 'quick', or 'settlement'
  final double totalAmount;
  final String? photoPath;
  final DateTime billDate;
  final DateTime createdAt;
  final String category;
  final int? recurringBillId;
  final int? receiverMemberId; // only used for settlements: who receives the payment
  final String? remoteId;
  final String? updatedAt;
  final String? photoUrl;
  final int? deletedByMemberId;

  Bill({
    this.id,
    required this.householdId,
    required this.enteredByMemberId,
    required this.paidByMemberId,
    required this.billType,
    required this.totalAmount,
    this.photoPath,
    required this.billDate,
    DateTime? createdAt,
    this.category = 'other',
    this.recurringBillId,
    this.receiverMemberId,
    this.remoteId,
    this.updatedAt,
    this.photoUrl,
    this.deletedByMemberId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'entered_by_member_id': enteredByMemberId,
      'paid_by_member_id': paidByMemberId,
      'bill_type': billType,
      'total_amount': totalAmount,
      'photo_path': photoPath,
      'bill_date': billDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'category': category,
      'recurring_bill_id': recurringBillId,
      'receiver_member_id': receiverMemberId,
      'remote_id': remoteId,
      'updated_at': updatedAt,
      'photo_url': photoUrl,
      'deleted_by_member_id': deletedByMemberId,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      enteredByMemberId: map['entered_by_member_id'] as int,
      paidByMemberId: map['paid_by_member_id'] as int,
      billType: map['bill_type'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      photoPath: map['photo_path'] as String?,
      billDate: DateTime.parse(map['bill_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      category: map['category'] as String? ?? 'other',
      recurringBillId: map['recurring_bill_id'] as int?,
      receiverMemberId: map['receiver_member_id'] as int?,
      remoteId: map['remote_id'] as String?,
      updatedAt: map['updated_at'] as String?,
      photoUrl: map['photo_url'] as String?,
      deletedByMemberId: map['deleted_by_member_id'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bill && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
