import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/member.dart';

class ItemRow extends StatelessWidget {
  final String name;
  final double price;
  final bool isIncluded;
  final List<Member> allMembers;
  final List<int> selectedMemberIds;
  final ValueChanged<List<int>> onMembersChanged;
  final String currencySymbol;

  const ItemRow({
    super.key,
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.allMembers,
    required this.selectedMemberIds,
    required this.onMembersChanged,
    this.currencySymbol = '\u20BA',
  });

  void _toggleMember(int memberId) {
    final isSelected = selectedMemberIds.contains(memberId);

    // Prevent deselecting the last remaining member.
    if (isSelected && selectedMemberIds.length <= 1) return;

    final updated = isSelected
        ? selectedMemberIds.where((id) => id != memberId).toList()
        : [...selectedMemberIds, memberId];

    onMembersChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 14, AppSpacing.lg, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name and price
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${price.toStringAsFixed(2)} $currencySymbol',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Member chips
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (int i = 0; i < allMembers.length; i++)
                    _MemberChip(
                      member: allMembers[i],
                      color: AppColors.memberColor(i),
                      isSelected:
                          selectedMemberIds.contains(allMembers[i].id),
                      isDark: isDark,
                      onTap: () => _toggleMember(allMembers[i].id!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final Member member;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MemberChip({
    required this.member,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final letter = member.name.isNotEmpty
        ? member.name[0].toUpperCase()
        : '?';

    final bgColor = isSelected
        ? color.withAlpha(38)
        : (isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant);
    final borderColor = isSelected ? color : Colors.transparent;
    final textColor = isSelected
        ? color
        : (isDark ? AppColors.darkTextSecondary : AppColors.neutral);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : (isDark ? AppColors.darkDivider : AppColors.surfaceMuted),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              member.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
