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

  const ItemRow({
    super.key,
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.allMembers,
    required this.selectedMemberIds,
    required this.onMembersChanged,
  });

  static const _chipColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFF8B5CF6), // tertiary
    AppColors.positive,
    AppColors.accent,
    AppColors.negative,
  ];

  Color _colorForIndex(int index) => _chipColors[index % _chipColors.length];

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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${price.toStringAsFixed(2)} TL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Member chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < allMembers.length; i++)
                    _MemberChip(
                      member: allMembers[i],
                      color: _colorForIndex(i),
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

    final bgColor =
        isSelected ? color.withAlpha(30) : Colors.transparent;
    final borderColor =
        isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.border);
    final borderWidth = isSelected ? 2.0 : 1.0;
    final textColor =
        isSelected ? color : (isDark ? AppColors.textTertiary : AppColors.neutral);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.border),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : textColor,
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
