import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bill.dart';
import '../models/bill_filter.dart';
import '../models/member.dart';
import '../widgets/bill_list_tile.dart';

class FilteredResultsSheet extends StatelessWidget {
  final List<Bill> filteredBills;
  final BillFilter filter;
  final List<Member> members;
  final String currencySymbol;
  final ValueChanged<Bill> onBillTap;
  final VoidCallback onClearFilters;
  final ScrollController? scrollController;

  const FilteredResultsSheet({
    super.key,
    required this.filteredBills,
    required this.filter,
    required this.members,
    required this.currencySymbol,
    required this.onBillTap,
    required this.onClearFilters,
    this.scrollController,
  });

  String _buildFilterSummary() {
    final parts = <String>[];
    if (filter.category != null) {
      parts.add(BillCategories.getById(filter.category!).label);
    }
    if (filter.memberId != null) {
      final name = members
          .where((m) => m.id == filter.memberId)
          .firstOrNull
          ?.name ?? 'Unknown';
      parts.add('$name (${filter.filterByPaidBy ? 'paid by' : 'shared with'})');
    }
    if (filter.datePresetLabel != null) {
      parts.add(filter.datePresetLabel!);
    } else if (filter.dateFrom != null) {
      parts.add('Custom date range');
    }
    return parts.join(' \u2022 ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = filteredBills.fold(0.0, (sum, b) => sum + b.totalAmount);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),

          // Header with results count and total
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredBills.length} bill${filteredBills.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${total.toStringAsFixed(2)} $currencySymbol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _buildFilterSummary(),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  height: 1,
                ),
              ],
            ),
          ),

          // Bill list
          Flexible(
            child: filteredBills.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            'No bills match these filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              onClearFilters();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.darkDivider
                                    : AppColors.divider,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            child: const Text('Clear filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    itemCount: filteredBills.length,
                    itemBuilder: (context, index) {
                      final bill = filteredBills[index];
                      final paidBy = members
                          .where((m) => m.id == bill.paidByMemberId)
                          .firstOrNull;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: BillListTile(
                          bill: bill,
                          paidByName: paidBy?.name ?? 'Unknown',
                          currencySymbol: currencySymbol,
                          onTap: () {
                            Navigator.pop(context);
                            onBillTap(bill);
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Bottom action bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    onClearFilters();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Clear filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
