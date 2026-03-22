import 'package:flutter/material.dart';
import '../constants.dart';

class BalanceCard extends StatelessWidget {
  final int currentMemberId;
  final Map<int, double> memberBalances;
  final Map<int, Map<int, double>> pairwiseBalances;
  final Map<int, String> memberNames;
  final void Function(int memberId, double amount)? onSettleUp;
  final String currencySymbol;

  const BalanceCard({
    super.key,
    required this.currentMemberId,
    required this.memberBalances,
    required this.pairwiseBalances,
    required this.memberNames,
    this.onSettleUp,
    this.currencySymbol = '\u20BA',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myPairwise = pairwiseBalances[currentMemberId] ?? {};
    final otherEntries = <int, double>{};
    for (final entry in myPairwise.entries) {
      if (entry.value.abs() > 0.01) {
        otherEntries[entry.key] = entry.value;
      }
    }

    final allSettled = otherEntries.isEmpty;

    if (allSettled) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkTextSecondary : AppColors.textTertiary)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.handshake_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All settled up!',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final entry in otherEntries.entries)
            _BalanceRow(
              memberName: memberNames[entry.key] ?? 'Unknown',
              amount: entry.value,
              currencySymbol: currencySymbol,
              isDark: isDark,
              onSettleUp: onSettleUp != null
                  ? () => onSettleUp!(entry.key, entry.value.abs())
                  : null,
            ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String memberName;
  final double amount; // positive = they owe you, negative = you owe them
  final String currencySymbol;
  final bool isDark;
  final VoidCallback? onSettleUp;

  const _BalanceRow({
    required this.memberName,
    required this.amount,
    required this.currencySymbol,
    required this.isDark,
    this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final theyOweYou = amount > 0;
    final message = theyOweYou ? '$memberName owes you' : 'You owe $memberName';
    final absAmount = amount.abs();

    // Per-row colors: green when owed, red when owing
    final Color rowColor = theyOweYou ? AppColors.positive : AppColors.negative;
    final Color bgColor = theyOweYou
        ? (isDark ? AppColors.positive.withAlpha(20) : AppColors.positiveSurface)
        : (isDark ? AppColors.negative.withAlpha(20) : AppColors.negativeSurface);

    // Arrows: down = money coming to you (owed), up = money leaving (you owe)
    final IconData arrowIcon = theyOweYou
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rowColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(arrowIcon, color: rowColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: rowColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: absAmount),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Text(
                  '${value.toStringAsFixed(2)} $currencySymbol',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: rowColor,
                    letterSpacing: -0.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onSettleUp,
              style: FilledButton.styleFrom(
                backgroundColor: rowColor.withValues(alpha: 0.12),
                foregroundColor: rowColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.handshake_rounded, size: 16, color: rowColor),
                  const SizedBox(width: 6),
                  Text(
                    'Settle Up',
                    style: TextStyle(fontWeight: FontWeight.w600, color: rowColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
