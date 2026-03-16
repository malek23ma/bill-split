class BillItem {
  final int? id;
  final int billId;
  final String name;
  final double price;
  final bool isIncluded; // checkbox: true = split between members
  final int splitPercent; // default 50 = equal split

  BillItem({
    this.id,
    required this.billId,
    required this.name,
    required this.price,
    this.isIncluded = true,
    this.splitPercent = 50,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_id': billId,
      'name': name,
      'price': price,
      'is_included': isIncluded ? 1 : 0,
      'split_percent': splitPercent,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as int?,
      billId: map['bill_id'] as int,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      isIncluded: (map['is_included'] as int) == 1,
      splitPercent: map['split_percent'] as int,
    );
  }

  BillItem copyWith({
    int? id,
    int? billId,
    String? name,
    double? price,
    bool? isIncluded,
    int? splitPercent,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      price: price ?? this.price,
      isIncluded: isIncluded ?? this.isIncluded,
      splitPercent: splitPercent ?? this.splitPercent,
    );
  }
}
