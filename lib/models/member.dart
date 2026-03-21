class Member {
  final int? id;
  final int householdId;
  final String name;
  final String? pin;
  final bool isActive;
  final bool isAdmin;

  Member({
    this.id,
    required this.householdId,
    required this.name,
    this.pin,
    this.isActive = true,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'name': name,
      'pin': pin,
      'is_active': isActive ? 1 : 0,
      'is_admin': isAdmin ? 1 : 0,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
