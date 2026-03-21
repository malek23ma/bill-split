class Member {
  final int? id;
  final int householdId;
  final String name;
  final String? pin;

  Member({
    this.id,
    required this.householdId,
    required this.name,
    this.pin,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'household_id': householdId,
      'name': name,
      'pin': pin,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int?,
      householdId: map['household_id'] as int,
      name: map['name'] as String,
      pin: map['pin'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
