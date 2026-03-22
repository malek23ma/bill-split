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
    this.currencySymbol = '\u20BA',
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(bill.billDate);
    final isSettlement = bill.billType == 'settlement';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final category = BillCategories.getById(bill.category);

    final iconColor = isSettlement ? AppColors.positive : category.color;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16), vertical: AppScale.padding(4)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16), vertical: AppScale.padding(14)),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: AppScale.size(44),
                  height: AppScale.size(44),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    isSettlement ? Icons.handshake_rounded : category.icon,
                    color: iconColor,
                    size: AppScale.size(22),
                  ),
                ),
                SizedBox(width: AppScale.size(14)),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSettlement)
                        Row(
                          children: [
                            Icon(Icons.handshake_rounded,
                                size: AppScale.size(14), color: AppColors.positive),
                            const SizedBox(width: 4),
                            Text(
                              'Settled',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(15),
                                fontWeight: FontWeight.w700,
                                color: AppColors.positive,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '${bill.totalAmount.toStringAsFixed(2)} $currencySymbol',
                          style: TextStyle(
                            fontSize: AppScale.fontSize(16),
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        isSettlement
                            ? '$dateStr  \u00B7  ${bill.totalAmount.toStringAsFixed(2)} $currencySymbol'
                            : '$dateStr  \u00B7  Paid by $paidByName',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(12),
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing badge & chevron
                if (!isSettlement) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppScale.padding(8), vertical: AppScale.padding(3)),
                    decoration: BoxDecoration(
                      color: bill.billType == 'quick'
                          ? AppColors.accentSurface
                          : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      bill.billType == 'quick' ? 'Quick' : 'Full',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(11),
                        fontWeight: FontWeight.w600,
                        color: bill.billType == 'quick'
                            ? AppColors.accent
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: AppScale.size(20),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textTertiary),
                ],
                if (isSettlement)
                  Icon(Icons.chevron_right_rounded,
                      size: AppScale.size(20),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
