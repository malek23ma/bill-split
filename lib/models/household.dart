class Household {
  final int? id;
  final String name;
  final String currency;
  final DateTime createdAt;
  final String? remoteId;
  final String? updatedAt;

  Household({
    this.id,
    required this.name,
    this.currency = 'TRY',
    DateTime? createdAt,
    this.remoteId,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'remote_id': remoteId,
      'updated_at': updatedAt,
    };
  }

  factory Household.fromMap(Map<String, dynamic> map) {
    return Household(
      id: map['id'] as int?,
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'TRY',
      createdAt: DateTime.parse(map['created_at'] as String),
      remoteId: map['remote_id'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Household && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
