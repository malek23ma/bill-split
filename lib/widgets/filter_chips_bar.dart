import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../models/bill_filter.dart';
import '../models/member.dart';

class FilterChipsBar extends StatelessWidget {
  final BillFilter filter;
  final List<Member> members;
  final ValueChanged<BillFilter?> onFilterChanged;

  const FilterChipsBar({
    super.key,
    required this.filter,
    required this.members,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chips = <Widget>[];

    // Category chip
    if (filter.category != null) {
      final cat = BillCategories.getById(filter.category!);
      chips.add(_buildChip(
        context,
        icon: Icon(cat.icon, size: 16, color: cat.color),
        label: cat.label,
        isDark: isDark,
        onDeleted: () => _removeFilter(clearCategory: true),
      ));
    }

    // Member chip
    if (filter.memberId != null) {
      final member = members
          .where((m) => m.id == filter.memberId)
          .firstOrNull;
      final name = member?.name ?? 'Unknown';
      final suffix = filter.filterByPaidBy ? '(paid by)' : '(shared with)';
      chips.add(_buildChip(
        context,
        icon: Icon(Icons.person_rounded, size: 16,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        label: '$name $suffix',
        isDark: isDark,
        onDeleted: () => _removeFilter(clearMember: true),
      ));
    }

    // Date chip
    if (filter.dateFrom != null || filter.dateTo != null) {
      final dateLabel = filter.datePresetLabel ?? _formatDateRange();
      chips.add(_buildChip(
        context,
        icon: Icon(Icons.calendar_today_rounded, size: 16,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        label: dateLabel,
        isDark: isDark,
        onDeleted: () => _removeFilter(clearDate: true),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required Widget icon,
    required String label,
    required bool isDark,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      avatar: icon,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      deleteIcon: Icon(
        Icons.close_rounded,
        size: 16,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      onDeleted: onDeleted,
      backgroundColor:
          isDark ? AppColors.darkSurfaceVariant : AppColors.primarySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        side: BorderSide(
          color: isDark ? AppColors.darkDivider : AppColors.divider,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _removeFilter({
    bool clearCategory = false,
    bool clearMember = false,
    bool clearDate = false,
  }) {
    final updated = filter.copyWith(
      clearCategory: clearCategory,
      clearMemberId: clearMember,
      clearDateFrom: clearDate,
      clearDateTo: clearDate,
      clearDatePresetLabel: clearDate,
    );

    if (!updated.hasActiveFilters) {
      onFilterChanged(null);
    } else {
      onFilterChanged(updated);
    }
  }

  String _formatDateRange() {
    final fmt = DateFormat('dd/MM');
    final parts = <String>[];
    if (filter.dateFrom != null) parts.add(fmt.format(filter.dateFrom!));
    if (filter.dateTo != null) parts.add(fmt.format(filter.dateTo!));
    return parts.join(' - ');
  }
}
