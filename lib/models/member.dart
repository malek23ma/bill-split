class Member {
  final int? id;
  final int householdId;
  final String name;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;
  final String? remoteId;
  final String? updatedAt;
  final String? userId;

  Member({
    this.id,
    required this.householdId,
    required this.name,
    this.isActive = true,
    this.isAdmin = false,
    DateTime? createdAt,
    this.remoteId,
    this.updatedAt,
    this.userId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'is_admin': isAdmin ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'remote_id': remoteId,
      'updated_at': updatedAt,
      'user_id': userId,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      name: map['name'] as String,
      isActive: (map['is_active'] as int?) != 0,
      isAdmin: (map['is_admin'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime(2020), // fallback for pre-v8 rows
      remoteId: map['remote_id'] as String?,
      updatedAt: map['updated_at'] as String?,
      userId: map['user_id'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
