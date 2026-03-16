class Household {
  final int? id;
  final String name;
  final String currency;
  final DateTime createdAt;

  Household({
    this.id,
    required this.name,
    this.currency = 'TRY',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Household.fromMap(Map<String, dynamic> map) {
    return Household(
      id: map['id'] as int?,
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'TRY',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
