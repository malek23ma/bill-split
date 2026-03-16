class BillItem {
  final int? id;
  final int billId;
  final String name;
  final double price;
  final bool isIncluded; // checkbox: true = split between members
  final List<int> sharedByMemberIds; // member IDs sharing this item

  BillItem({
    this.id,
    required this.billId,
    required this.name,
    required this.price,
    this.isIncluded = true,
    this.sharedByMemberIds = const [],
    @Deprecated('Use sharedByMemberIds instead') int? splitPercent,
  });

  /// Backward-compatible getter for legacy code that still uses splitPercent.
  /// Will be removed when all screens are migrated to use sharedByMemberIds.
  @Deprecated('Use sharedByMemberIds instead')
  int get splitPercent {
    // Legacy compatibility: if no members assigned, default to 50 (shared)
    if (sharedByMemberIds.isEmpty) return 50;
    // Single member = 100 (mine), otherwise 50 (shared equally)
    return sharedByMemberIds.length == 1 ? 100 : 50;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_id': billId,
      'name': name,
      'price': price,
      'is_included': isIncluded ? 1 : 0,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map, {List<int> memberIds = const []}) {
    return BillItem(
      id: map['id'] as int?,
      billId: map['bill_id'] as int,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      isIncluded: (map['is_included'] as int) == 1,
      sharedByMemberIds: memberIds,
    );
  }

  BillItem copyWith({
    int? id,
    int? billId,
    String? name,
    double? price,
    bool? isIncluded,
    List<int>? sharedByMemberIds,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      price: price ?? this.price,
      isIncluded: isIncluded ?? this.isIncluded,
      sharedByMemberIds: sharedByMemberIds ?? this.sharedByMemberIds,
    );
  }
}
