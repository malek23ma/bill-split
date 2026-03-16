import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../constants.dart';

class BillListTile extends StatelessWidget {
  final Bill bill;
  final String paidByName;
  final VoidCallback onTap;
  final String currencySymbol;

  const BillListTile({
    super.key,
    required this.bill,
    required this.paidByName,
    required this.onTap,
    this.currencySymbol = '₺',
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(bill.billDate);
    final isSettlement = bill.billType == 'settlement';
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final category = BillCategories.getById(bill.category);

    final leadingColor = isSettlement ? AppColors.positive : category.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Colored left accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Leading icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: leadingColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isSettlement ? Icons.handshake : category.icon,
                    color: leadingColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSettlement)
                          Text(
                            'Settled up',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.positive,
                            ),
                          )
                        else
                          Text(
                            '${bill.totalAmount.toStringAsFixed(2)} $currencySymbol',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          isSettlement
                              ? '$dateStr  ·  ${bill.totalAmount.toStringAsFixed(2)} $currencySymbol'
                              : '$dateStr  ·  Paid by $paidByName',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Trailing badge & chevron
                if (!isSettlement) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bill.billType == 'quick'
                          ? AppColors.accent.withAlpha(20)
                          : AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                    ),
                    child: Text(
                      bill.billType == 'quick' ? 'Quick' : 'Full',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: bill.billType == 'quick'
                            ? AppColors.accent
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textTertiary),
                ],
                if (isSettlement)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.chevron_right,
                        size: 20, color: AppColors.textTertiary),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
