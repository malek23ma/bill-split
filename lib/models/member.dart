class Member {
  final int? id;
  final int householdId;
  final String name;
  final String? pin;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;

  Member({
    this.id,
    required this.householdId,
    required this.name,
    this.pin,
    this.isActive = true,
    this.isAdmin = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'name': name,
      'pin': pin,
      'is_active': isActive ? 1 : 0,
      'is_admin': isAdmin ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      name: map['name'] as String,
      pin: map['pin'] as String?,
      isActive: (map['is_active'] as int?) != 0,
      isAdmin: (map['is_admin'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime(2020), // fallback for pre-v8 rows
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
