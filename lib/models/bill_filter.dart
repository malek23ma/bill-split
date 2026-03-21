class BillFilter {
  final String? category;
  final int? memberId;
  final bool filterByPaidBy; // true = "paid by", false = "shared with"
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? datePresetLabel;

  const BillFilter({
    this.category,
    this.memberId,
    this.filterByPaidBy = true,
    this.dateFrom,
    this.dateTo,
    this.datePresetLabel,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// Because all filterable fields are nullable, the standard `??` pattern
  /// cannot distinguish between "not provided" and "explicitly set to null."
  /// Use the corresponding `clear*` flag to reset a field to null:
  ///
  /// ```dart
  /// filter.copyWith(category: 'Food');          // set category
  /// filter.copyWith(clearCategory: true);       // reset category to null
  /// ```
  BillFilter copyWith({
    String? category,
    int? memberId,
    bool? filterByPaidBy,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? datePresetLabel,
    // Clear flags — set to true to null-out the corresponding field.
    bool clearCategory = false,
    bool clearMemberId = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearDatePresetLabel = false,
  }) {
    return BillFilter(
      category: clearCategory ? null : (category ?? this.category),
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      filterByPaidBy: filterByPaidBy ?? this.filterByPaidBy,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      datePresetLabel: clearDatePresetLabel
          ? null
          : (datePresetLabel ?? this.datePresetLabel),
    );
  }

  /// Whether any filter field is active.
  bool get hasActiveFilters =>
      category != null ||
      memberId != null ||
      dateFrom != null ||
      dateTo != null;

  /// Number of distinct active filter groups (category, member, date range).
  int get activeFilterCount {
    int count = 0;
    if (category != null) count++;
    if (memberId != null) count++;
    if (dateFrom != null || dateTo != null) count++;
    return count;
  }
}
